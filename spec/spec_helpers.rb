require 'simplecov'

SimpleCov.start

RSpec.configure do |rspec|
  rspec.shared_context_metadata_behavior = :apply_to_host_groups
end

shared_context 'basic parameters' do
  let(:stack_id) { 'ze-id' }
  let(:stack_name) { 'ze-stack' }
end

shared_context 'yaml configs' do
  let :config_yaml do
    data = <<EOF
Format: v1
Tags:
 - Name: tlevel
   Value: top
Parameters:
 - Name: plevel
   Value: top
Variants:
 level1_a:
   Tags:
     - Name: tlevel
       Value: level1_a
 level1_b:
   DefaultPath: level2_a
   Variants:
     level2_a:
       Parameters:
         - Name: plevel
           Value: level2_a
     level2_b:
       Parameters:
         - Name: plevel
           Value: level2_b
EOF
  end

  let :config_file do
    config = Tempfile.new('metadata')
    config.write(config_yaml)
    config.close
    config
  end
end

shared_context 'metadata' do
  include_context 'basic parameters'

  let(:s3url) { 's3://foo/bar' }
  let :meta do
    meta = CuffSert::StackConfig.new
    meta.selected_path = [stack_name.split(/-/)]
    meta.tags = {'k1' => 'v1', 'k2' => 'v2'}
    meta.stack_uri = URI.parse(s3url)
    meta
  end
end

shared_context 'templates' do
  let(:template_json) { '{}' }
  let :template_body do
    body = Tempfile.new('template_body')
    body.write(template_json)
    body.rewind
    body
  end
end

shared_context 'changesets' do
  let(:change_set_id) { 'ze-change-set-id' }

  let :stack_update_change_set do
    { :id => change_set_id, :stack_id => 'ze-stack' }
  end

  let :r1_modify do
    {
      :action => 'Modify',
      :replacement => 'True',
      :logical_resource_id => 'resource1_id',
    }
  end

  let :r2_add do
    {
      :action => 'Add',
      :replacement => 'False',
      :logical_resource_id => 'resource2_id',
    }
  end

  let :r3_delete do
    {
      :action => 'Delete',
      :replacement => 'False',
      :logical_resource_id => 'resource3_id',
    }
  end

  let :change_set_changes do
    []
  end

  let :change_set_in_progress do
    {
      :change_set_id => change_set_id,
      :stack_id => stack_id,
      :stack_name => stack_name,
      :status => 'CREATE_IN_PROGRESS',
    }
  end

  let :change_set_ready do
    {
      :change_set_id => change_set_id,
      :stack_id => stack_id,
      :stack_name => stack_name,
      :status => 'CREATE_COMPLETE',
      :changes => change_set_changes,
    }
  end
end

shared_context 'stack states' do
  include_context 'basic parameters'

  let :stack_complete do
    {
      :stack_id => stack_id,
      :stack_name => stack_name,
      :stack_status => 'CREATE_COMPLETE',
    }
  end

  let :stack_in_progress do
    {
      :stack_id => stack_id,
      :stack_name => stack_name,
      :stack_status => 'CREATE_IN_PROGRESS',
    }
  end

  let :stack_rolled_back do
    {
      :stack_id => stack_id,
      :stack_name => stack_name,
      :stack_status => 'ROLLBACK_COMPLETE',
    }
  end

  let :stack_complete_describe do
    {:stacks => [stack_complete]}
  end

  let :stack_in_progress_describe do
    {:stacks => [stack_in_progress]}
  end

  let :stack_rolled_back_describe do
    {:stacks => [stack_rolled_back]}
  end
end

shared_context 'stack events' do
  let :r1_done do
    {
      :event_id => 'r1_done',
      :stack_id => stack_id,
      :logical_resource_id => 'resource1_id',
      :resource_status => 'CREATE_COMPLETE',
      :timestamp => '2013-08-23T01:02:28.025Z',
    }
  end

  let :r2_progress do
    {
      :event_id => 'r2_progress',
      :stack_id => stack_id,
      :logical_resource_id => 'resource2_id',
      :resource_status => 'CREATE_IN_PROGRESS',
      :timestamp => '2013-08-23T01:02:28.025Z',
    }
  end

  let :r2_done do
    {
      :event_id => 'r2_done',
      :stack_id => stack_id,
      :logical_resource_id => 'resource2_id',
      :resource_status => 'CREATE_COMPLETE',
      :timestamp => '2013-08-23T01:02:38.534Z',
    }
  end

  let :r2_rolled_back do
    {
      :event_id => 'r2_rolled_back',
      :stack_id => stack_id,
      :logical_resource_id => 'resource2_id',
      :resource_status => 'DELETE_COMPLETE',
      :timestamp => '2013-08-23T01:02:38.534Z',
    }
  end

  let :stack_in_progress_events do
    { :stack_events => [r1_done, r2_progress] }
  end

  let :stack_complete_events do
    { :stack_events => [r1_done, r2_done] }
  end

  let :stack_rolled_back_events do
    {:stack_events => [r1_done, r2_rolled_back] }
  end
end

def observe_expect(subject)
  result = []
  error = nil
  Thread.new do
    spinlock = 1
    subject.subscribe(
      lambda { |event| result << event },
      lambda { |err| error = err ; spinlock -= 1 },
      lambda { spinlock -= 1 }
    )

    for n in 1..10
      break if spinlock == 0
      sleep(0.05)
    end
    raise 'timeout' if spinlock == 1
  end.join
  raise error if error
  expect(result)
end
