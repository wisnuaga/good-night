require "rails_helper"

RSpec.describe RepairSleepRecordFanoutJob, type: :job do
  let(:user_id) { 1 }
  let(:lock_key) { "repair_lock:#{user_id}" }

  let(:followee_ids_batch_1) { [2, 3] }
  let(:followee_ids_batch_2) { [4] }

  let(:existing_ids) { [10, 11] }

  let(:sleep_record_repo) { instance_double("SleepRecordRepository") }
  let(:fanout_repo) { instance_double("FanoutRepository") }
  let(:follow_repo) { instance_double("FollowRepository") }

  let(:records_batch_1) do
    [
      OpenStruct.new(id: 12, clock_in: Time.parse("2025-05-25 10:00:00"), clock_out: Time.parse("2025-05-25 07:00:00"), sleep_time: 3.hours.to_f),
      OpenStruct.new(id: 13, clock_in: Time.parse("2025-05-26 09:00:00"), clock_out: Time.parse("2025-05-26 04:00:00"), sleep_time: 5.hours.to_f)
    ]
  end

  let(:records_batch_2) do
    [
      OpenStruct.new(id: 14, clock_in: Time.parse("2025-05-26 08:00:00"), sleep_time: 0.0)
    ]
  end

  before do
    allow($redis).to receive(:set).with(lock_key, true, nx: true, ex: 60).and_return(true)
    allow($redis).to receive(:del).with(lock_key)

    allow(SleepRecordRepository).to receive(:new).and_return(sleep_record_repo)
    allow(FanoutRepository).to receive(:new).and_return(fanout_repo)
    allow(FollowRepository).to receive(:new).and_return(follow_repo)

    allow(fanout_repo).to receive(:list_fanout).with(user_id: user_id).and_return(existing_ids)
    allow(fanout_repo).to receive(:add_to_feed)

    # Followee batch calls - outer loop
    allow(follow_repo).to receive(:list_followee_ids_batch)
                            .with(user_id: user_id, cursor: nil, limit: 10)
                            .and_return([followee_ids_batch_1, "cursor-1"])

    allow(follow_repo).to receive(:list_followee_ids_batch)
                            .with(user_id: user_id, cursor: "cursor-1", limit: 10)
                            .and_return([followee_ids_batch_2, nil])
  end

  describe "#perform" do
    context "when lock is acquired" do
      before do
        # Sleep records for first batch (includes user_id appended)
        allow(sleep_record_repo).to receive(:list_by_user_ids)
                                      .with(user_ids: followee_ids_batch_1 + [user_id], cursor: nil)
                                      .and_return(records_batch_1)

        # On next call with cursor from last sleep_time of records_batch_1, return empty to end inner loop
        allow(sleep_record_repo).to receive(:list_by_user_ids)
                                      .with(user_ids: followee_ids_batch_1 + [user_id], cursor: records_batch_1.last.sleep_time)
                                      .and_return([])

        # Sleep records for second batch (no self user_id appended)
        allow(sleep_record_repo).to receive(:list_by_user_ids)
                                      .with(user_ids: followee_ids_batch_2, cursor: nil)
                                      .and_return(records_batch_2)

        # Next call cursor from last sleep_time of records_batch_2 returns empty
        allow(sleep_record_repo).to receive(:list_by_user_ids)
                                      .with(user_ids: followee_ids_batch_2, cursor: records_batch_2.last.sleep_time)
                                      .and_return([])
      end

      it "adds only missing records to the feed and releases the lock" do
        described_class.perform_now(user_id)

        # It should add all records with IDs not in existing_ids
        expect(fanout_repo).to have_received(:add_to_feed).with(user_id: user_id, sleep_record: records_batch_1[0])
        expect(fanout_repo).to have_received(:add_to_feed).with(user_id: user_id, sleep_record: records_batch_1[1])
        expect(fanout_repo).to have_received(:add_to_feed).with(user_id: user_id, sleep_record: records_batch_2[0])
        expect($redis).to have_received(:del).with(lock_key)
      end
    end

    context "when lock is not acquired" do
      it "returns early without doing anything" do
        allow($redis).to receive(:set).with(lock_key, true, nx: true, ex: 60).and_return(false)
        expect(SleepRecordRepository).not_to receive(:new)
        expect($redis).not_to receive(:del)

        described_class.perform_now(user_id)
      end
    end

    context "when an error occurs" do
      before do
        allow(SleepRecordRepository).to receive(:new).and_raise(StandardError.new("boom"))
        allow(Rails.logger).to receive(:error)
      end

      it "logs the error and releases the lock" do
        described_class.perform_now(user_id)
        expect(Rails.logger).to have_received(:error).with("[RepairSleepRecordFanoutJob] Failed for user #{user_id}: boom")
        expect($redis).to have_received(:del).with(lock_key)
      end
    end
  end
end
