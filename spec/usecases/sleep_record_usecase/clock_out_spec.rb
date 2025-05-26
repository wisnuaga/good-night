require "rails_helper"

RSpec.describe SleepRecordUsecase::ClockOut do
  let(:user) { instance_double("User", id: 1) }
  let(:sleep_record_repo) { instance_double(SleepRecordRepository) }
  let(:follow_repo) { instance_double(FollowRepository) }
  let(:session) { double(clock_out: nil, save: true) }
  let(:usecase) { described_class.new(user, sleep_record_repository: sleep_record_repo, follow_repository: follow_repo, clock_out: Time.current) }

  context "when active session exists" do
    before do
      allow(sleep_record_repo).to receive(:find_active_by_user).with(user.id).and_return(session)
    end

    it "returns success" do
      allow(session).to receive(:clock_out=)
      result = usecase.call
      expect(result.success?).to be true
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
