require "rails_helper"

RSpec.describe SleepRecordUsecase::ClockIn do
  let(:user) { instance_double("User", id: 1) }
  let(:sleep_record_repo) { instance_double(SleepRecordRepository) }
  let(:follow_repo) { instance_double(FollowRepository) }
  let(:clock_in_time) { Time.current }
  let(:usecase) { described_class.new(user, sleep_record_repository: sleep_record_repo, follow_repository: follow_repo, clock_in: clock_in_time) }
  let(:persisted_record) { instance_double("SleepRecord", id: 123, persisted?: true, user_id: user.id, clock_in: clock_in_time) }
  let(:follower_ids) { [1, 2, 3] }

  before do
    # Stub follower_ids fetch for background job call inside usecase (if any)
    allow(follow_repo).to receive(:list_follower_ids).with(user_id: user.id).and_return(follower_ids - [user.id])
  end

  context "when user has no active session" do
    before do
      allow(sleep_record_repo).to receive(:find_active_by_user).with(user_id: user.id).and_return(nil)
      allow(sleep_record_repo).to receive(:create).and_return(persisted_record)

      # Expect the background job to be enqueued with record ID and follower IDs including user.id
      allow(SleepRecordFanoutJob).to receive(:perform_later)
    end

    it "returns success" do
      result = usecase.call
      expect(result.success?).to be true
    end

    it "enqueues background job to fanout" do
      usecase.call
      expected_follower_ids = (follower_ids + [user.id]).uniq
      expect(SleepRecordFanoutJob).to have_received(:perform_later).with(persisted_record.id, match_array(expected_follower_ids))
    end
  end

  context "when user has an active session" do
    before do
      allow(sleep_record_repo).to receive(:find_active_by_user).with(user_id: user.id).and_return(instance_double("SleepRecord", persisted?: true))
    end

    it "returns failure" do
      result = usecase.call
      expect(result.success?).to be false
      expect(result.error).to eq("You already have an active sleep session")
    end
  end
end
