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
  end

  context "when user or followee is not found" do
    it "does nothing if user is nil" do
      allow(user_repo).to receive(:find_by_id).with(user_id).and_return(nil)
      allow(user_repo).to receive(:find_by_id).with(unfollowed_user_id).and_return(followee)

      expect(follow_repo).not_to receive(:exists?)
      expect(fanout_repo).not_to receive(:remove_from_feed)

      described_class.perform_now(user_id, unfollowed_user_id)
    end

    it "does nothing if followee is nil" do
      allow(user_repo).to receive(:find_by_id).with(user_id).and_return(user)
      allow(user_repo).to receive(:find_by_id).with(unfollowed_user_id).and_return(nil)

      expect(follow_repo).not_to receive(:exists?)
      expect(fanout_repo).not_to receive(:remove_from_feed)

      described_class.perform_now(user_id, unfollowed_user_id)
    end
  end

  context "when user is still following followee" do
    it "does nothing" do
      allow(user_repo).to receive(:find_by_id).with(user_id).and_return(user)
      allow(user_repo).to receive(:find_by_id).with(unfollowed_user_id).and_return(followee)
      allow(follow_repo).to receive(:exists?).with(follower: user, followee: followee).and_return(true)

      expect(fanout_repo).not_to receive(:remove_from_feed)

      described_class.perform_now(user_id, unfollowed_user_id)
    end
  end

  context "when unfollowed and records exist" do
    it "removes records in batches from feed" do
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

      described_class.perform_now(user_id, unfollowed_user_id)
    end
  end
end
