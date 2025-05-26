require "rails_helper"

RSpec.describe SleepRecordFanoutJob, type: :job do
  let(:sleep_record) { instance_double("SleepRecord", id: 123) }
  let(:follower_ids) { [1, 2, 3] }
  let(:sleep_record_repo) { instance_double("SleepRecordRepository") }
  let(:fanout_repo) { instance_double("FanoutRepository") }

  before do
    allow(SleepRecordRepository).to receive(:new).and_return(sleep_record_repo)
    allow(FanoutRepository).to receive(:new).and_return(fanout_repo)
  end

  describe "#perform" do
    context "when sleep record exists" do
      before do
        allow(sleep_record_repo).to receive(:find_by_id).with(sleep_record.id).and_return(sleep_record)
        allow(fanout_repo).to receive(:write_fanout)
      end

      it "calls write_fanout with correct arguments" do
        described_class.perform_now(sleep_record.id, follower_ids)
        expect(fanout_repo).to have_received(:write_fanout).with(sleep_record: sleep_record, follower_ids: follower_ids)
      end
    end

    context "when sleep record does not exist" do
      before do
        allow(sleep_record_repo).to receive(:find_by_id).with(sleep_record.id).and_return(nil)
      end

      it "does not call write_fanout" do
        expect(fanout_repo).not_to receive(:write_fanout)
        described_class.perform_now(sleep_record.id, follower_ids)
      end
    end

    context "when an exception occurs" do
      let(:error_message) { "Something went wrong" }

      before do
        allow(sleep_record_repo).to receive(:find_by_id).with(sleep_record.id).and_return(sleep_record)
        allow(fanout_repo).to receive(:write_fanout).and_raise(StandardError.new(error_message))
        allow(Rails.logger).to receive(:error)
      end

      it "logs the error" do
        described_class.perform_now(sleep_record.id, follower_ids)
        expect(Rails.logger).to have_received(:error).with("[SleepRecordFanoutJob] Failed for record #{sleep_record.id}: #{error_message}")
      end
    end
  end
end
