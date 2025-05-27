require 'rails_helper'

RSpec.describe SleepRecordRepository do
  let(:repo) { described_class.new }
  let(:user) { User.create!(name: "Alice") }

  before do
    SleepRecord.delete_all
  end

  describe "#list_by_user_ids" do
    let(:user2) { create(:user) }
    let(:now) { Time.zone.now }

    before do
      SleepRecord.delete_all
    end

    it "returns sleep records for given user ids ordered by sleep_time desc" do
      now = Time.current
      record1 = SleepRecord.create!(user: user, clock_in: now - 2.hours, clock_out: now - 1.hour)
      record2 = SleepRecord.create!(user: user, clock_in: now - 5.hours, clock_out: now - 3.hours)

      records = repo.list_by_user_ids(user_ids: [user.id])

      expect(records).to eq([record2, record1])
    end

    it "returns records for multiple user ids" do
      now = Time.current
      record1 = SleepRecord.create!(user: user, clock_in: now - 2.hours, clock_out: now - 1.hour)
      record2 = SleepRecord.create!(user: user2, clock_in: now - 1.hour, clock_out: now - 0.5.hour)

      records = repo.list_by_user_ids(user_ids: [user.id, user2.id])

      expect(records).to include(record1, record2)
      expect(records.map(&:user_id).uniq.sort).to eq([user.id, user2.id].sort)
    end

    it "applies cursor to return records with sleep_time < cursor" do
      record1 = SleepRecord.create!(user: user, clock_in: now - 2.hours, clock_out: now - 1.hours)
      record2 = SleepRecord.create!(user: user, clock_in: now - 8.hours, clock_out: now - 3.hour)

      cursor = (now - 3.hours).to_f

      records = repo.list_by_user_ids(user_ids: [user.id], cursor: cursor)

      # Expect the first returned record to be record2 (clock_in < cursor)
      expect(records.first).to eq(record2)
    end

    it "limits the number of records returned" do
      now = Time.current
      3.times do |i|
        SleepRecord.create!(user: user, clock_in: now - (i + 1).hours, clock_out: now - i.hours)
      end

      records = repo.list_by_user_ids(user_ids: [user.id], limit: 2)

      expect(records.length).to eq(2)
      expect(records.first.clock_in).to be > records.last.clock_in
    end
  end

  describe "#list_by_ids" do
    let(:user) { create(:user) }

    it "returns records by given ids limited" do
      r1 = SleepRecord.create!(user: user, clock_in: 5.hours.ago, clock_out: 4.hours.ago)
      r2 = SleepRecord.create!(user: user, clock_in: 3.hours.ago, clock_out: 2.hours.ago)
      r3 = SleepRecord.create!(user: user, clock_in: 2.hours.ago, clock_out: 1.hours.ago)
      result = repo.list_by_ids(ids: [r1.id, r2.id, r3.id], limit: 2)
      expect(result.size).to eq(2)
    end
  end

  describe "#count_by_user_ids" do
    let(:user) { create(:user) }

    before do
      stub_const("Repository::FEED_TTL_SECONDS", 86400)
      stub_const("Repository::FEED_LIST_LIMIT", 2)
    end

    it "counts records after FEED_SINCE_LIMIT and caps at FEED_LIST_LIMIT" do
      SleepRecord.create!(user: user, clock_in: 2.days.ago, clock_out: 1.day.ago)  # old record, before limit
      SleepRecord.create!(user: user, clock_in: 20.hours.ago, clock_out: 19.hours.ago)
      SleepRecord.create!(user: user, clock_in: 18.hours.ago, clock_out: 17.hours.ago)
      SleepRecord.create!(user: user, clock_in: 16.hours.ago, clock_out: 15.hours.ago)

      count = repo.count_by_user_ids(user_ids: [user.id])

      # We have 3 recent records, but FEED_LIST_LIMIT is 2, so count is capped to 2
      expect(count).to eq(2)
    end

    it "returns 0 if no records after FEED_SINCE_LIMIT" do
      SleepRecord.create!(user: user, clock_in: 2.days.ago, clock_out: 1.day.ago)

      count = repo.count_by_user_ids(user_ids: [user.id])

      expect(count).to eq(0)
    end
  end

  describe "#find_active_by_user" do
    it "returns nil if there is no active sleep record" do
      SleepRecord.create!(user: user, clock_in: 3.hours.ago, clock_out: 2.hours.ago)

      active = repo.find_active_by_user(user.id)

      expect(active).to be_nil
    end

    it "returns the active sleep record for the user" do
      # Create a finished session first
      SleepRecord.create!(user: user, clock_in: 3.hours.ago, clock_out: 2.hours.ago)

      # Then create the active session
      active_record = SleepRecord.create!(user: user, clock_in: 1.hour.ago, clock_out: nil)

      active = repo.find_active_by_user(user.id)

      expect(active).to eq(active_record)
      expect(active.clock_out).to be_nil
    end
  end

  describe "#create" do
    it "creates a valid sleep record" do
      sleep_record = repo.create(user_id: user.id, clock_in: Time.current - 1.hour)

      expect(sleep_record).to be_persisted
      expect(sleep_record.clock_out).to be_nil
    end

    it "returns nil if record is invalid (e.g., another active session exists)" do
      # Create an active record
      repo.create(user_id: user.id, clock_in: Time.current - 2.hours)

      # Attempt to create another active record (should fail)
      sleep_record = repo.create(user_id: user.id, clock_in: Time.current - 1.hour)

      expect(sleep_record).to be_nil
    end
  end
end
