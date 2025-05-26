require 'rails_helper'

RSpec.describe SleepRecordUsecase::List do
  let(:user) { instance_double("User", id: 1) }
  let(:sleep_record_repo) { instance_double(SleepRecordRepository) }
  let(:follow_repo) { instance_double(FollowRepository) }
  let(:fanout_repo) { instance_double(FanoutRepository) }
  let(:usecase) { described_class.new(user, sleep_record_repository: sleep_record_repo, follow_repository: follow_repo, fanout_repository: fanout_repo) }

  let(:record1) { instance_double("SleepRecord", id: 101, clock_in: 1_686_470_000) }
  let(:record2) { instance_double("SleepRecord", id: 102, clock_in: 1_686_470_100) }

  describe "#call" do
    context "when fanout is empty (fallback to DB)" do
      it "fetches from DB and schedules cache repair" do
        expect(fanout_repo).to receive(:list_fanout)
                                       .with(user_id: user.id, cursor: nil, limit: 10)
                                       .and_return([])

        expect(follow_repo).to receive(:list_followee_ids)
                                 .with(user_id: user.id)
                                 .and_return([2, 3])

        expect(sleep_record_repo).to receive(:list_by_user_ids)
                                       .with(user_ids: [2, 3, 1], cursor: nil, limit: 10)
                                       .and_return([record1, record2])

        expect(RepairSleepRecordCacheJob).to receive(:perform_later)
                                               .with(user.id, [2, 3, 1])

        result = usecase.call(limit: 10)

        expect(result.success?).to be true
        expect(result.data[:data]).to eq([record1, record2])
      end
    end

    context "when fanout returns results" do
      it "uses fanout and does not call list_by_user_ids" do
        fanout_ids = [101, 102, 103]
        records = [
          instance_double("SleepRecord", id: 101, clock_in: 1_686_470_200),
          instance_double("SleepRecord", id: 102, clock_in: 1_686_470_300),
          instance_double("SleepRecord", id: 103, clock_in: 1_686_470_400)
        ]

        expect(fanout_repo).to receive(:list_fanout)
                                       .with(user_id: user.id, cursor: nil, limit: 10)
                                       .and_return(fanout_ids)

        expect(follow_repo).to receive(:list_followee_ids)
                                 .with(user_id: user.id)
                                 .and_return([2, 3])

        expect(sleep_record_repo).to receive(:list_by_ids)
                                       .with(ids: fanout_ids)
                                       .and_return(records)

        expect(sleep_record_repo).to receive(:count_by_user_ids)
                                       .with(user_ids: [2, 3, 1], cursor: nil, limit: 10)
                                       .and_return(fanout_ids.size)

        result = usecase.call(limit: 10)

        expect(result.success?).to be true
        expect(result.data[:data]).to eq(records)
      end
    end

    context "when cache is stale (missing_count exceeds threshold)" do
      it "schedules RepairSleepRecordCacheJob" do
        fanout_ids = [101, 102, 103]
        records = fanout_ids.map.with_index do |id, i|
          instance_double("SleepRecord", id: id, clock_in: 1_686_470_200 + (i * 100))
        end

        expect(fanout_repo).to receive(:list_fanout)
                                       .with(user_id: user.id, cursor: nil, limit: 10)
                                       .and_return(fanout_ids)

        expect(follow_repo).to receive(:list_followee_ids)
                                 .with(user_id: user.id)
                                 .and_return([2, 3])

        expect(sleep_record_repo).to receive(:list_by_ids)
                                       .with(ids: fanout_ids)
                                       .and_return(records)

        # total_records is more than fanout_ids size by threshold + 1
        total_records = fanout_ids.size + described_class::MIN_THRESHOLD + 1

        expect(sleep_record_repo).to receive(:count_by_user_ids)
                                       .with(user_ids: [2, 3, 1], cursor: nil, limit: 10)
                                       .and_return(total_records)

        expect(RepairSleepRecordCacheJob).to receive(:perform_later)
                                               .with(user.id, [2, 3, 1])

        result = usecase.call(limit: 10)

        expect(result.success?).to be true
        expect(result.data[:data]).to eq(records)
      end
    end

    context "when a cursor is provided" do
      it "decodes and passes cursor to repository method" do
        cursor_time = 1_686_470_000
        limit = 5
        cursor = Pagination::CursorHelper.encode_cursor(cursor_time)

        expect(fanout_repo).to receive(:list_fanout)
                                       .with(user_id: user.id, cursor: cursor_time, limit: limit)
                                       .and_return([])

        expect(follow_repo).to receive(:list_followee_ids)
                                 .with(user_id: user.id)
                                 .and_return([2, 3])

        expect(sleep_record_repo).to receive(:list_by_user_ids)
                                       .with(user_ids: [2, 3, 1], cursor: cursor_time, limit: limit)
                                       .and_return([record1, record2])

        expect(RepairSleepRecordCacheJob).to receive(:perform_later)
                                               .with(user.id, [2, 3, 1])

        result = usecase.call(cursor: cursor, limit: limit)

        expect(result.success?).to be true
        expect(result.data[:data]).to eq([record1, record2])
        expect(result.data[:next_cursor]).to be_nil
      end
    end

    context "when user is not found" do
      it "returns failure with user error" do
        allow(fanout_repo).to receive(:list_fanout)
                                .and_raise(UsecaseError::UserNotFoundError.new("User not found"))

        result = usecase.call(limit: 10)

        expect(result.success?).to be false
        expect(result.error).to eq("User not found")
      end
    end

    context "when unexpected error occurs" do
      it "returns failure with error message" do
        allow(fanout_repo).to receive(:list_fanout)
                                .and_raise(StandardError.new("Some error"))

        result = usecase.call(limit: 10)

        expect(result.success?).to be false
        expect(result.error).to include("Unexpected error: Some error")
      end
    end
  end
end
