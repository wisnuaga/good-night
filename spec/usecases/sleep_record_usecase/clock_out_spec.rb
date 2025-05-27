require "rails_helper"

RSpec.describe SleepRecordUsecase::ClockOut do
  let(:user) { instance_double("User", id: 1) }
  let(:sleep_record_repo) { instance_double(SleepRecordRepository) }
  let(:follow_repo) { instance_double(FollowRepository) }
  let(:session) do
    instance_double("SleepRecord", id: 42, save: true).tap do |s|
      allow(s).to receive(:clock_out=)
    end
  end
  let(:usecase) { described_class.new(user, sleep_record_repository: sleep_record_repo, follow_repository: follow_repo, clock_out: Time.current) }

  context "when active session exists and follower count within fanout limit" do
    let(:follower_ids) { [1, 2, 3] }  # small enough follower count

    before do
      allow(sleep_record_repo).to receive(:find_active_by_user).with(user.id).and_return(session)
      allow(follow_repo).to receive(:list_follower_ids).with(user_id: user.id, limit: Repository::FANOUT_LIMIT + 1).and_return(follower_ids - [user.id])
      allow(SleepRecordFanoutJob).to receive(:perform_later)
    end

    it "returns success" do
      result = usecase.call
      expect(result.success?).to be true
    end

    it "enqueues background job to fanout" do
      usecase.call
      expected_follower_ids = (follower_ids + [user.id]).uniq
      expect(SleepRecordFanoutJob).to have_received(:perform_later).with(session.id, match_array(expected_follower_ids))
    end

    it "does not log skipping fanout" do
      expect(Rails.logger).not_to receive(:info).with(/Skipping fanout/)
      usecase.call
    end
  end

  context "when active session exists and follower count exceeds fanout limit" do
    let(:large_follower_count) { Repository::FANOUT_LIMIT + 1 }
    let(:follower_ids) { (2..large_follower_count).to_a }

    before do
      allow(sleep_record_repo).to receive(:find_active_by_user).with(user.id).and_return(session)
      allow(follow_repo).to receive(:list_follower_ids).with(user_id: user.id, limit: Repository::FANOUT_LIMIT + 1).and_return(follower_ids - [user.id])
      allow(SleepRecordFanoutJob).to receive(:perform_later)
    end

    it "returns success" do
      result = usecase.call
      expect(result.success?).to be true
    end

    it "does NOT enqueue background job to fanout" do
      usecase.call
      expect(SleepRecordFanoutJob).not_to have_received(:perform_later)
    end

    it "logs skipping fanout due to large follower count" do
      expect(Rails.logger).to receive(:info).with(
        "[SleepRecordUsecase::ClockOut] Skipping fanout for user #{user.id} due to follower count (#{large_follower_count}) exceeding limit #{Repository::FANOUT_LIMIT}. Will fanout on read."
      )
      usecase.call
    end
  end

  context "when no active session exists" do
    before do
      allow(sleep_record_repo).to receive(:find_active_by_user).with(user.id).and_return(nil)
    end

    it "returns failure" do
      result = usecase.call
      expect(result.success?).to be false
      expect(result.error).to eq("No active sleep session found")
    end
  end
end
