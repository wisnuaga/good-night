require "rails_helper"

RSpec.describe RepairSleepRecordCacheJob, type: :job do
  let(:user_id) { 1 }
  let(:followee_ids) { [2, 3] }
  let(:lock_key) { "repair_lock:#{user_id}" }
  let(:redis_key) { "feed:#{user_id}" }
  let(:repo) { instance_double("SleepRecordRepository") }
  let(:existing_ids) { [10, 11] }
  let(:feed_limit) { SleepRecordRepository::FEED_LIST_LIMIT }
  let(:feed_ttl) { SleepRecordRepository::FEED_TTL_SECONDS }

  before do
    stub_const("SleepRecordRepository::FEED_LIST_LIMIT", 3)
    stub_const("SleepRecordRepository::FEED_TTL_SECONDS", 3600)

    allow(SleepRecordRepository).to receive(:new).and_return(repo)
    allow(repo).to receive(:list_fanout).with(user_id: user_id).and_return(existing_ids)
  end

  describe "#perform" do
    context "when lock is acquired" do
      before do
        allow($redis).to receive(:set).with(lock_key, true, nx: true, ex: 60).and_return(true)
        allow(repo).to receive(:list_by_user_ids)
                         .with(user_ids: followee_ids, cursor: nil, limit: feed_limit)
                         .and_return(records_batch_1)
        allow(repo).to receive(:list_by_user_ids)
                         .with(user_ids: followee_ids, cursor: last_clock_in_in_batch_1, limit: feed_limit - records_batch_1.size)
                         .and_return(records_batch_2)
        allow(repo).to receive(:list_by_user_ids)
                         .with(user_ids: followee_ids, cursor: last_clock_in_in_batch_2, limit: feed_limit - (records_batch_1.size + records_batch_2.size))
                         .and_return([])
      end

      let(:records_batch_1) do
        [
          OpenStruct.new(id: 12, clock_in: Time.parse("2025-05-26 10:00:00")),
          OpenStruct.new(id: 13, clock_in: Time.parse("2025-05-26 09:00:00"))
        ]
      end
      let(:last_clock_in_in_batch_1) { records_batch_1.last.clock_in }
      let(:records_batch_2) do
        [
          OpenStruct.new(id: 14, clock_in: Time.parse("2025-05-26 08:00:00"))
        ]
      end
      let(:last_clock_in_in_batch_2) { records_batch_2.last.clock_in }

      it "fetches correct records, updates redis, trims and expires feed" do
        allow($redis).to receive(:zadd)
        allow($redis).to receive(:zremrangebyrank)
        allow($redis).to receive(:expire)

        described_class.perform_now(user_id, followee_ids)

        # Check zadd called only for missing records (12,13,14), excluding existing_ids (10,11)
        expect($redis).to have_received(:zadd).with(redis_key, records_batch_1[0].clock_in.to_i, records_batch_1[0].id)
        expect($redis).to have_received(:zadd).with(redis_key, records_batch_1[1].clock_in.to_i, records_batch_1[1].id)
        expect($redis).to have_received(:zadd).with(redis_key, records_batch_2[0].clock_in.to_i, records_batch_2[0].id)

        # Check trimming call respects the feed limit
        expect($redis).to have_received(:zremrangebyrank).with(redis_key, 0, -feed_limit - 1)

        # Check expire called with correct TTL
        expect($redis).to have_received(:expire).with(redis_key, feed_ttl)
      end
    end

    context "when lock is not acquired" do
      it "returns early without doing anything" do
        allow($redis).to receive(:set).with(lock_key, true, nx: true, ex: 60).and_return(false)
        expect_any_instance_of(SleepRecordRepository).not_to receive(:list_fanout)
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
        expect(Rails.logger).to have_received(:error).with("[RepairSleepRecordCacheJob] Failed for user #{user_id}: boom")
      end
    end
  end
end
