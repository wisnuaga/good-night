require "rails_helper"

RSpec.describe RepairSleepRecordFanoutJob, type: :job do
  let(:user_id) { 1 }
  let(:followee_ids) { [2, 3] }
  let(:lock_key) { "repair_lock:#{user_id}" }
  let(:redis_key) { "feed:#{user_id}" }
  let(:sleep_record_repo) { instance_double("SleepRecordRepository") }
  let(:fanout_repo) { instance_double("FanoutRepository") }
  let(:existing_ids) { [10, 11] }
  let(:feed_limit) { 3 }
  let(:feed_ttl) { 3600 }

  before do
    stub_const("SleepRecordRepository::FEED_LIST_LIMIT", feed_limit)
    stub_const("SleepRecordRepository::FEED_TTL_SECONDS", feed_ttl)

    allow(SleepRecordRepository).to receive(:new).and_return(sleep_record_repo)
    allow(FanoutRepository).to receive(:new).and_return(fanout_repo)
    allow(fanout_repo).to receive(:list_fanout).with(user_id: user_id).and_return(existing_ids)
  end

  describe "#perform" do
    context "when lock is acquired" do
      let(:records_batch_1) do
        [
          OpenStruct.new(id: 12, clock_in: Time.parse("2025-05-26 10:00:00")),
          OpenStruct.new(id: 13, clock_in: Time.parse("2025-05-26 09:00:00"))
        ]
      end
      let(:records_batch_2) do
        [
          OpenStruct.new(id: 14, clock_in: Time.parse("2025-05-26 08:00:00"))
        ]
      end

      before do
        allow($redis).to receive(:set).with(lock_key, true, nx: true, ex: 60).and_return(true)

        allow(sleep_record_repo).to receive(:list_by_user_ids)
                                      .with(user_ids: followee_ids, cursor: nil, limit: feed_limit)
                                      .and_return(records_batch_1)

        allow(sleep_record_repo).to receive(:list_by_user_ids)
                                      .with(user_ids: followee_ids, cursor: records_batch_1.last.clock_in, limit: feed_limit - records_batch_1.size)
                                      .and_return(records_batch_2)

        allow(sleep_record_repo).to receive(:list_by_user_ids)
                                      .with(user_ids: followee_ids, cursor: records_batch_2.last.clock_in, limit: feed_limit - (records_batch_1.size + records_batch_2.size))
                                      .and_return([])

        allow(fanout_repo).to receive(:add_to_feed)
      end

      it "adds only missing records to feed" do
        described_class.perform_now(user_id, followee_ids)

        expect(fanout_repo).to have_received(:add_to_feed).with(user_id: user_id, sleep_record: records_batch_1[0])
        expect(fanout_repo).to have_received(:add_to_feed).with(user_id: user_id, sleep_record: records_batch_1[1])
        expect(fanout_repo).to have_received(:add_to_feed).with(user_id: user_id, sleep_record: records_batch_2[0])
      end
    end

    context "when lock is not acquired" do
      it "returns early without doing anything" do
        allow($redis).to receive(:set).with(lock_key, true, nx: true, ex: 60).and_return(false)
        expect(SleepRecordRepository).not_to receive(:new)
        described_class.perform_now(user_id, followee_ids)
      end
    end

    context "when an error occurs" do
      before do
        allow($redis).to receive(:set).and_return(true)
        allow(SleepRecordRepository).to receive(:new).and_raise(StandardError.new("boom"))
        allow(Rails.logger).to receive(:error)
      end

      it "logs the error" do
        described_class.perform_now(user_id, followee_ids)
        expect(Rails.logger).to have_received(:error).with("[RepairSleepRecordFanoutJob] Failed for user #{user_id}: boom")
      end
    end
  end
end
