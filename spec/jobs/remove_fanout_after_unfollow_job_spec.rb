require "rails_helper"

RSpec.describe RemoveFanoutAfterUnfollowJob, type: :job do
  let(:user_id) { 1 }
  let(:unfollowed_user_id) { 2 }
  let(:user) { instance_double(User) }
  let(:followee) { instance_double(User) }
  let(:user_repo) { instance_double(UserRepository) }
  let(:follow_repo) { instance_double(FollowRepository) }
  let(:sleep_record_repo) { instance_double(SleepRecordRepository) }
  let(:fanout_repo) { instance_double(FanoutRepository) }
  let(:lock_key) { "remove_lock:#{user_id}" }

  before do
    stub_const("UserRepository", Class.new)
    stub_const("FollowRepository", Class.new)
    stub_const("SleepRecordRepository", Class.new)
    stub_const("FanoutRepository", Class.new)

    allow(UserRepository).to receive(:new).and_return(user_repo)
    allow(FollowRepository).to receive(:new).and_return(follow_repo)
    allow(SleepRecordRepository).to receive(:new).and_return(sleep_record_repo)
    allow(FanoutRepository).to receive(:new).and_return(fanout_repo)

    stub_const("SleepRecordRepository::FEED_LIST_LIMIT", 10)

    # Default Redis behavior: lock acquired
    allow($redis).to receive(:set).with(lock_key, true, nx: true, ex: 60).and_return(true)
    allow($redis).to receive(:del)
  end

  context "when Redis lock is NOT acquired" do
    it "returns immediately and does not run the job" do
      allow($redis).to receive(:set).with(lock_key, true, nx: true, ex: 60).and_return(false)

      expect(user_repo).not_to receive(:find_by_id)
      expect(follow_repo).not_to receive(:exists?)
      expect(fanout_repo).not_to receive(:remove_from_feed)
      expect($redis).not_to receive(:del)

      described_class.perform_now(user_id, unfollowed_user_id)
    end
  end

  context "when Redis lock is acquired" do
    context "when user or followee is not found" do
      it "does nothing if user is nil" do
        allow(user_repo).to receive(:find_by_id).with(user_id).and_return(nil)
        allow(user_repo).to receive(:find_by_id).with(unfollowed_user_id).and_return(followee)

        expect(follow_repo).not_to receive(:exists?)
        expect(fanout_repo).not_to receive(:remove_from_feed)
        expect($redis).to receive(:del).with(lock_key)

        described_class.perform_now(user_id, unfollowed_user_id)
      end

      it "does nothing if followee is nil" do
        allow(user_repo).to receive(:find_by_id).with(user_id).and_return(user)
        allow(user_repo).to receive(:find_by_id).with(unfollowed_user_id).and_return(nil)

        expect(follow_repo).not_to receive(:exists?)
        expect(fanout_repo).not_to receive(:remove_from_feed)
        expect($redis).to receive(:del).with(lock_key)

        described_class.perform_now(user_id, unfollowed_user_id)
      end
    end

    context "when user is still following followee" do
      it "does nothing" do
        allow(user_repo).to receive(:find_by_id).with(user_id).and_return(user)
        allow(user_repo).to receive(:find_by_id).with(unfollowed_user_id).and_return(followee)
        allow(follow_repo).to receive(:exists?).with(follower: user, followee: followee).and_return(true)

        expect(fanout_repo).not_to receive(:remove_from_feed)
        expect($redis).to receive(:del).with(lock_key)

        described_class.perform_now(user_id, unfollowed_user_id)
      end
    end

    context "when unfollowed and records exist" do
      it "removes records in batches from feed and releases lock" do
        allow(user_repo).to receive(:find_by_id).with(user_id).and_return(user)
        allow(user_repo).to receive(:find_by_id).with(unfollowed_user_id).and_return(followee)
        allow(follow_repo).to receive(:exists?).with(follower: user, followee: followee).and_return(false)

        record1 = double(:record, id: 1, sleep_time: Time.current)
        record2 = double(:record, id: 2, sleep_time: Time.current + 1.minute)

        allow(sleep_record_repo).to receive(:list_by_user_ids)
                                      .with(user_ids: [unfollowed_user_id], cursor: nil, limit: SleepRecordRepository::FEED_LIST_LIMIT)
                                      .and_return([record1, record2])
        allow(sleep_record_repo).to receive(:list_by_user_ids)
                                      .with(user_ids: [unfollowed_user_id], cursor: record2.sleep_time, limit: SleepRecordRepository::FEED_LIST_LIMIT)
                                      .and_return([])

        expect(fanout_repo).to receive(:remove_from_feed).with(user_id: user_id, sleep_record_ids: [1, 2])
        expect($redis).to receive(:del).with(lock_key)

        described_class.perform_now(user_id, unfollowed_user_id)
      end
    end

    context "when an error occurs" do
      it "logs the error and does NOT release the lock" do
        allow(user_repo).to receive(:find_by_id).with(user_id).and_raise(StandardError.new("Something went wrong"))
        allow(user_repo).to receive(:find_by_id).with(unfollowed_user_id).and_return(followee)

        expect(Rails.logger).to receive(:error).with(/\[RemoveFanoutAfterUnfollowJob\] Failed for user #{user_id} unfollowed #{unfollowed_user_id}: Something went wrong/)
        expect($redis).to receive(:del)

        described_class.perform_now(user_id, unfollowed_user_id)
      end
    end

  end
end
