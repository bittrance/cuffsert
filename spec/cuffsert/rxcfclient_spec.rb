require 'cuffsert/metadata'
require 'cuffsert/rxcfclient'
require 'date'
require 'rx-rspec'
require 'spec_helpers'

describe CuffSert::RxCFClient do
  include_context 'metadata'
  include_context 'stack states'
  include_context 'stack events'
  include_context 'changesets'

  before do
    allow(DateTime).to receive(:now)
      .and_return(DateTime.rfc3339('2013-08-23T01:02:00.000Z'))
  end

  let :cfargs do
    {}
  end

  describe '#find_stack_blocking' do
    context 'finds a stack' do
      let :aws_mock do
        mock = double(:aws_mock)
        expect(mock).to receive(:describe_stacks)
          .with(:stack_name => stack_name)
          .and_return(stack_complete_describe)
        mock
      end

      subject { described_class.new(aws_mock, pause: 0).find_stack_blocking(meta) }

      it { should include(:stack_name => stack_name) }
    end

    context 'finds nothing' do
      let :aws_validation_error do
        Aws::CloudFormation::Errors::ValidationError.new(
          nil, 'Stack with id production does not exist'
        )
      end

      let :aws_mock do
        mock = double(:aws_mock)
        expect(mock).to receive(:describe_stacks)
          .and_raise(aws_validation_error)
        mock
      end

      subject { described_class.new(aws_mock, pause: 0).find_stack_blocking(meta) }

      it { should be(nil) }
    end
  end

  describe '#create_stack' do
    let(:create_reply) { {:stack_id => stack_id} }

    let :aws_mock do
      mock = double(:aws_mock)
      expect(mock).to receive(:create_stack)
        .and_return(create_reply)
      expect(mock).to receive(:describe_stack_events)
        .with(:stack_name => stack_id)
        .at_least(:twice)
        .and_return(*events_sequence)
      mock
    end

    context 'events when create is succesful' do
      let :events_sequence do
        [
          [stack_in_progress_events, too_old_events],
          [stack_complete_events, stack_in_progress_events, too_old_events]
        ]
      end

      subject { described_class.new(aws_mock, pause: 0).create_stack(cfargs) }

      it { expect(subject).to emit_exactly(r1_done, r2_progress, r2_done, s1_done) }
    end

    context 'events when create failed with rollback' do
      let :events_sequence do
        [
          [stack_in_progress_events],
          [stack_rolled_back_events, stack_in_progress_events]
        ]
      end

      subject { described_class.new(aws_mock, pause: 0).create_stack(cfargs) }

      it { expect(subject).to emit_exactly(r1_done, r2_progress, r2_deleted, s1_rolled) }
    end
  end

  describe '#prepare update' do
    let :aws_mock do
      mock = double(:aws_mock)
      expect(mock).to receive(:create_change_set)
        .and_return(stack_update_change_set)
      mock
    end

    subject { described_class.new(aws_mock, pause: 0).prepare_update(cfargs) }

    it 'returns change_set when ready' do
      expect(aws_mock).to receive(:describe_change_set)
        .at_least(:twice)
        .with(:change_set_name => change_set_id)
        .and_return(
          change_set_in_progress,
          change_set_ready
        )
      expect(subject).to emit_include(change_set_ready)
    end

    it 'returns change_set when failing' do
      expect(aws_mock).to receive(:describe_change_set)
        .once
        .with(:change_set_name => change_set_id)
        .and_return(change_set_failed)
      expect(subject).to emit_include(change_set_failed)
    end
  end

  describe '#update stack' do
    let :aws_mock do
      mock = double(:aws_mock)

      expect(mock).to receive(:execute_change_set)
        .with(include(:change_set_name => change_set_id))
        .and_return(nil)
      expect(mock).to receive(:describe_stack_events)
        .with(including(:stack_name => stack_id))
        .at_least(:twice)
        .and_return(
          [stack_in_progress_events],
          [stack_complete_events, stack_in_progress_events]
        )
      mock
    end

    subject { described_class.new(aws_mock, pause: 0).update_stack(stack_id, change_set_id) }

    it { expect(subject).to emit_exactly(r1_done, r2_progress, r2_done, s1_done) }
  end

  describe '#delete_stack' do
    let :aws_mock do
      mock = double(:aws_mock)
      expect(mock).to receive(:delete_stack)
        .and_return(nil)
      expect(mock).to receive(:describe_stack_events)
        .with(:stack_name => stack_id)
        .at_least(:twice)
        .and_return(*events_sequence)
      expect(mock).to receive(:describe_stacks)
        .at_least(:twice)
        .and_return(*stack_sequence)
      mock
    end

    context 'events when delete is succesful' do
      let(:cfargs) { {:stack_name => stack_id} }
      let :events_sequence do
        [
          [too_old_events, stack_deleting_events],
          [stack_deleted_events]
        ]
      end

      let :stack_sequence do
        [
          stack_deleting_describe,
          stack_deleted_describe
        ]
      end

      subject { described_class.new(aws_mock, pause: 0).delete_stack(cfargs) }

      it { should emit_exactly(r1_deleted, r2_deleting, r2_deleted) }
    end
  end
end
