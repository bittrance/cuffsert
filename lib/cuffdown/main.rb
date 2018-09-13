require 'cuffsert/metadata'
require 'cuffsert/rxcfclient'
require 'yaml'

module CuffDown
  def self.parameters(stack)
    (stack[:parameters] || []).map do |param|
      {
        'Name' => param[:parameter_key],
        'Value' => param[:parameter_value],
      }
    end
  end

  def self.tags(stack)
    (stack[:tags] || []).map do |param|
      {
        'Name' => param[:key],
        'Value' => param[:value],
      }
    end
  end

  def self.dump(name, params, tags, output)
    result = {
      'Format' => 'v1',
      'Suffix' => name,
      'Parameters' => params,
      'Tags' => tags,
    }
    YAML.dump(result, output)
  end

  def self.run(args, output)
    meta = CuffSert::StackConfig.new
    meta.stackname = args[0]
    client = CuffSert::RxCFClient.new({})
    stack = client.find_stack_blocking(meta)
    unless stack
      STDERR.puts "No such stack #{meta.stackname}"
      exit(1)
    end
    stack = stack.to_h
    self.dump(
      stack[:stack_name],
      self.parameters(stack),
      self.tags(stack),
      output
    )
  end
end
