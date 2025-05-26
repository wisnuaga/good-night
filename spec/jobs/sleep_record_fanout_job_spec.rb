require "rails_helper"

RSpec.describe SleepRecordFanoutJob, type: :job do
  let(:sleep_record) { instance_double("SleepRecord", id: 123) }
  let(:follower_ids) { [1, 2, 3] }
  let(:repository) { instance_double("SleepRecordRepository") }

  before do
    allow(SleepRecordRepository).to receive(:new).and_return(repository)
  end

  describe "#perform" do
    context "when sleep record exists" do
      before do
        allow(SleepRecord).to receive(:find_by).with(id: sleep_record.id).and_return(sleep_record)
        allow(repository).to receive(:fanout_to_followers)
      end

      it "calls fanout_to_followers with correct arguments" do
        described_class.perform_now(sleep_record.id, follower_ids)
        expect(repository).to have_received(:fanout_to_followers).with(sleep_record: sleep_record, follower_ids: follower_ids)
      end
    end

    context "when sleep record does not exist" do
      before do
        allow(SleepRecord).to receive(:find_by).with(id: sleep_record.id).and_return(nil)
      end

      it "does not call fanout_to_followers" do
        expect(repository).not_to receive(:fanout_to_followers)
        described_class.perform_now(sleep_record.id, follower_ids)
      end
    end

    context "when an exception occurs" do
      let(:error_message) { "Something went wrong" }

      before do
        allow(SleepRecord).to receive(:find_by).with(id: sleep_record.id).and_return(sleep_record)
        allow(repository).to receive(:fanout_to_followers).and_raise(StandardError.new(error_message))
        allow(Rails.logger).to receive(:error)
      end

      it "logs the error" do
        described_class.perform_now(sleep_record.id, follower_ids)
        expect(Rails.logger).to have_received(:error).with("[SleepRecordFanoutJob] Failed for record #{sleep_record.id}: #{error_message}")
      end
    end
  end
end
