require 'cuffdown/main'
require 'spec_helpers'

describe CuffDown do
  include_context 'stack states'

  describe '.run' do
    let(:cli_args) { ['some-stack'] }
    let(:output) { StringIO.new }
    let :stack_complete do
      super().merge(
        :parameters => [
          {:parameter_key => 'p1', :parameter_value => 'v1'}
        ]
      )
    end

    let(:cfmock) { double(:cfmock) }

    before do
      allow(Aws::CloudFormation::Client).to receive(:new).and_return(cfmock)
      allow(cfmock).to receive(:describe_stacks).and_return(stack_complete_describe)
      CuffDown.run(cli_args, output)
    end

    it 'outputs parameter values for the stack' do
      expect(output.string).to match(/Name: p1.*Value: v1/m)
    end
  end
end