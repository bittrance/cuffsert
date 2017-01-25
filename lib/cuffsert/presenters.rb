require 'aws-sdk'
require 'colorize'
require 'cuffsert/cfstates'
require 'rx'

# TODO: Animate in-progress states
# - Introduce a Done message and stop printing in on_complete
# - Present the error message in change_set properly - and abort

module CuffSert
  class BasePresenter
    def initialize(events)
      events.subscribe(
        method(:on_event),
        method(:on_error),
        method(:on_complete)
      )
    end

    def on_error(err)
      STDERR.puts'Error:'
      STDERR.puts err
      STDERR.puts err.backtrace.join("\n\t")
    end

    def on_complete
    end

    def update_width(width)
    end
  end

  class RawPresenter < BasePresenter
    def on_event(event)
      puts event.inspect
    end

    def on_complete
      puts 'Done.'
    end
  end

  class RendererPresenter < BasePresenter
    def initialize(events, renderer)
      @resources = []
      @index = {}
      @renderer = renderer
      super(events)
    end

    def on_event(event)
      # Workaround for now
      event = event.data if event.class == Seahorse::Client::Response

      case event
      when Aws::CloudFormation::Types::StackEvent
        on_stack_event(event)
      when Aws::CloudFormation::Types::DescribeChangeSetOutput
        on_change_set(event)
      # when [:recreate, Aws::CloudFormation::Types::Stack]
      when Array
        on_stack(*event)
      when ::CuffSert::Abort
        @renderer.abort(event)
      else
        puts event
      end
    end

    def on_complete
      @renderer.done
    end

    private

    def on_change_set(change_set)
      @renderer.change_set(change_set.to_h)
    end

    def on_stack_event(event)
      resource = lookup_stack_resource(event)
      update_resource_states(resource, event)
      @renderer.event(event, resource)
      @renderer.clear
      @resources.each { |resource| @renderer.resource(resource) }
    end

    def on_stack(event, stack)
      @renderer.stack(event, stack)
    end

    def lookup_stack_resource(event)
      rid = event[:logical_resource_id]
      unless (pos = @index[rid])
        pos = @index[rid] = @resources.size
        @resources << make_resource(event)
      end
      @resources[pos]
    end

    def make_resource(event)
      event.to_h
        .reject { |k, _| k == :timestamp }
        .merge!(:states => [])
    end

    def update_resource_states(resource, event)
      resource[:states] = resource[:states].reject do |state|
        state == :progress
      end << CuffSert.state_category(event[:resource_status])
    end
  end

  ACTION_ORDER = ['Add', 'Modify', 'Replace?', 'Replace!', 'Delete']

  class ProgressbarRenderer
    def initialize(output = STDOUT)
      @output = output
    end

    def change_set(change_set)
      @output.write(sprintf("Updating %s\n", change_set[:stack_name]))
      change_set[:changes].sort do |l, r|
        lr = l[:resource_change]
        rr = r[:resource_change]
        [
          ACTION_ORDER.index(action(lr)),
          lr[:logical_resource_id]
        ] <=> [
          ACTION_ORDER.index(action(rr)),
          rr[:logical_resource_id]
        ]
      end.map do |change|
        rc = change[:resource_change]
        sprintf("%s[%s] %-10s %s\n",
          rc[:logical_resource_id],
          rc[:resource_type],
          action_color(action(rc)),
          rc[:scope]
        )
      end.each { |row| @output.write(row) }
    end

    def action(rc)
      if rc[:action] == 'Modify'
        if ['True', 'Always'].include?(rc[:replacement])
          'Replace!'
        elsif ['False', 'Never'].include?(rc[:replacement])
          'Modify'
        elsif rc[:replacement] == 'Conditional'
          'Replace?'
        else
          "#{rc[:action]}/#{rc[:replacement]}"
        end
      else
        rc[:action]
      end
    end

    def action_color(action)
      action.colorize(
        case action
        when 'Add' then :green
        when 'Modify' then :yellow
        else :red
        end
      )
    end

    def event(event, resource)
      if resource[:states][-1] == :bad
        message = sprintf('%s  %s[%s] %s',
          event[:timestamp].strftime('%H:%M:%S%z'),
          event[:logical_resource_id],
          event[:resource_type],
          event[:resource_status_reason]
        ).colorize(:red)
        @output.write("\r#{message}\n")
      end
    end

    def stack(event, stack)
      case event
      when :recreate
        message = sprintf(
          "Will delete and re-create %s",
          stack[:stack_name]
        )
        @output.write(message.colorize(:red) + "\n")
      else
        puts event, stack
      end
    end

    def clear
      @output.write("\r")
    end

    def resource(resource)
      color, symbol = case resource[:states]
      when [:progress]
        [:yellow, :tripple_dot]
      when [:good]
        [:green, :check]
      when [:bad]
        [:red, :cross]
      when [:good, :progress]
        [:light_white, :tripple_dot]
      when [:bad, :progress]
        [:red, :tripple_dot]
      when [:good, :good], [:bad, :good]
        [:light_white, :check]
      when [:good, :bad], [:bad, :bad]
        [:red, :qmark]
      else
        raise "Unexpected :states in #{resource.inspect}"
      end

      table = {
        :check => "+",
        :tripple_dot => ".", # "\u2026"
        :cross  => "!",
        :qmark => "?",
      }

      @output.write(table[symbol].colorize(
        :color => :white,
        :background => color
      ))
    end

    def abort(event)
      @output.write(event.message.colorize(:red) + "\n")
    end

    def done
      @output.write("\nDone.\n".colorize(:green))
    end
  end
end
