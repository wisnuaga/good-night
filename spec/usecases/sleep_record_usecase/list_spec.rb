require 'rails_helper'

RSpec.describe SleepRecordUsecase::List do
  let(:user) { instance_double("User", id: 1) }
  let(:sleep_record_repo) { instance_double(SleepRecordRepository) }
  let(:follow_repo) { instance_double(FollowRepository) }

  let(:usecase) { described_class.new(user, sleep_record_repository: sleep_record_repo, follow_repository: follow_repo) }

  # Create a fake record double with clock_in method
  let(:record1) { instance_double("SleepRecord", clock_in: 1_686_470_000) }
  let(:record2) { instance_double("SleepRecord", clock_in: 1_686_470_100) }

  context "general behavior" do
    it "falls back to list_by_user_ids for user and followees when fanout is empty" do
      expect(sleep_record_repo).to receive(:list_fanout).with(user_id: user.id).and_return([])

      expect(follow_repo).to receive(:list_followee_ids).with(user_id: user.id).and_return([2, 3])

      expect(sleep_record_repo).to receive(:list_by_user_ids)
                                     .with(user_ids: [2, 3, 1], cursor: nil, limit: described_class::CURSOR_LIMIT)
                                     .and_return([record1, record2])

      result = usecase.call

      expect(result.success?).to be true
      expect(result.data[:data]).to eq([record1, record2])
    end

    it "returns fanout results if present, without calling list_by_user_ids" do
      # Use doubles that respond to clock_in here as well
      fanout_records = [
        instance_double("SleepRecord", clock_in: 1_686_470_200),
        instance_double("SleepRecord", clock_in: 1_686_470_300),
        instance_double("SleepRecord", clock_in: 1_686_470_400)
      ]

      expect(sleep_record_repo).to receive(:list_fanout).with(user_id: user.id).and_return(fanout_records)

      expect(follow_repo).to receive(:list_followee_ids).with(user_id: user.id).and_return([2, 3])

      expect(sleep_record_repo).to receive(:list_by_ids)
                                     .with(ids: fanout_records, cursor: nil, limit: described_class::CURSOR_LIMIT)
                                     .and_return(fanout_records)

      expect(sleep_record_repo).to receive(:count_by_user_ids)
                                     .with(user_ids: [2, 3, 1])
                                     .and_return(fanout_records.size)

      result = usecase.call

      expect(result.success?).to be true
      expect(result.data[:data]).to eq(fanout_records)
    end
  end
end
