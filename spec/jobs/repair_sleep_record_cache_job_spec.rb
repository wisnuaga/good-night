require "rails_helper"

RSpec.describe RepairSleepRecordFanoutJob, type: :job do
  let(:user_id) { 1 }
  let(:followee_ids_batch_1) { [2, 3] }
  let(:followee_ids_batch_2) { [4] }
  let(:lock_key) { "repair_lock:#{user_id}" }
  let(:existing_ids) { [10, 11] }
  let(:feed_limit) { 3 }
  let(:feed_ttl) { 3600 }

  let(:sleep_record_repo) { instance_double("SleepRecordRepository") }
  let(:fanout_repo) { instance_double("FanoutRepository") }
  let(:follow_repo) { instance_double("FollowRepository") }

  let(:records_batch_1) do
    [
      OpenStruct.new(id: 12, clock_in: Time.parse("2025-05-25 10:00:00"), clock_out: Time.parse("2025-05-25 07:00:00"), sleep_time: (Time.parse("2025-05-25 10:00:00") - Time.parse("2025-05-25 07:00:00").to_f)),
      OpenStruct.new(id: 13, clock_in: Time.parse("2025-05-26 09:00:00"), clock_out: Time.parse("2025-05-26 04:00:00"), sleep_time: (Time.parse("2025-05-26 09:00:00") - Time.parse("2025-05-26 04:00:00").to_f))
    ]
  end

  let(:records_batch_2) do
    [
      OpenStruct.new(id: 14, clock_in: Time.parse("2025-05-26 08:00:00"))
    ]
  end

  before do
    stub_const("SleepRecordRepository::FEED_LIST_LIMIT", feed_limit)
    stub_const("SleepRecordRepository::FEED_TTL_SECONDS", feed_ttl)
    stub_const("Repository::FANOUT_LIMIT", 2)

    allow($redis).to receive(:set).with(lock_key, true, nx: true, ex: 60).and_return(true)

    allow(SleepRecordRepository).to receive(:new).and_return(sleep_record_repo)
    allow(FanoutRepository).to receive(:new).and_return(fanout_repo)
    allow(FollowRepository).to receive(:new).and_return(follow_repo)

    allow(fanout_repo).to receive(:list_fanout).with(user_id: user_id).and_return(existing_ids)
    allow(fanout_repo).to receive(:add_to_feed)
  end

  describe "#perform" do
    context "when lock is acquired" do
      before do
        # First call to list_followee_ids_batch returns first batch and cursor
        allow(follow_repo).to receive(:list_followee_ids_batch)
                                .with(user_id: user_id, cursor: nil, limit: 2)
                                .and_return([followee_ids_batch_1, "cursor-1"])

        # Second call returns another batch and nil cursor (end)
        allow(follow_repo).to receive(:list_followee_ids_batch)
                                .with(user_id: user_id, cursor: "cursor-1", limit: 2)
                                .and_return([followee_ids_batch_2, nil])

        # First batch of sleep records
        allow(sleep_record_repo).to receive(:list_by_user_ids)
                                      .with(user_ids: followee_ids_batch_1 + [user_id], cursor: nil, limit: 3)
                                      .and_return(records_batch_1)

        # Second batch of sleep records
        allow(sleep_record_repo).to receive(:list_by_user_ids)
                                      .with(user_ids: followee_ids_batch_2, cursor: records_batch_1.last.sleep_time, limit: 1)
                                      .and_return(records_batch_2)

        # Third call should return empty to break the loop
        allow(sleep_record_repo).to receive(:list_by_user_ids)
                                      .with(user_ids: followee_ids_batch_2, cursor: records_batch_2.last.sleep_time, limit: 0)
                                      .and_return([])
      end

      it "adds only missing records to the feed" do
        described_class.perform_now(user_id)

        expect(fanout_repo).to have_received(:add_to_feed).with(user_id: user_id, sleep_record: records_batch_1[0])
        expect(fanout_repo).to have_received(:add_to_feed).with(user_id: user_id, sleep_record: records_batch_1[1])
        expect(fanout_repo).to have_received(:add_to_feed).with(user_id: user_id, sleep_record: records_batch_2[0])
      end
    end

    context "when lock is not acquired" do
      it "returns early without doing anything" do
        allow($redis).to receive(:set).with(lock_key, true, nx: true, ex: 60).and_return(false)
        expect(SleepRecordRepository).not_to receive(:new)

        described_class.perform_now(user_id)
      end
    end

    context "when an error occurs" do
      before do
        allow($redis).to receive(:set).and_return(true)
        allow(SleepRecordRepository).to receive(:new).and_raise(StandardError.new("boom"))
        allow(Rails.logger).to receive(:error)
      end

      it "logs the error" do
        described_class.perform_now(user_id)
        expect(Rails.logger).to have_received(:error).with("[RepairSleepRecordFanoutJob] Failed for user #{user_id}: boom")
      end
    end
  end
end
