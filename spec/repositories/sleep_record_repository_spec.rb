require 'rails_helper'

RSpec.describe SleepRecordRepository do
  let(:repo) { described_class.new }
  let(:user) { User.create!(name: "Alice") }

  before do
    SleepRecord.delete_all
  end

  describe "#list_by_user_ids" do
    it "returns sleep records for given user ids ordered by clock_in desc" do
      record1 = SleepRecord.create!(user: user, clock_in: 2.hours.ago, clock_out: 1.hour.ago)
      record2 = SleepRecord.create!(user: user, clock_in: 4.hours.ago, clock_out: 3.hours.ago)

      records = repo.list_by_user_ids([user.id])

      expect(records).to eq([record1, record2])
    end
  end

  describe "#find_active_by_user" do
    it "returns nil if there is no active sleep record" do
      SleepRecord.create!(user: user, clock_in: 3.hours.ago, clock_out: 2.hours.ago)

      active = repo.find_active_by_user(user_id: user.id)

      expect(active).to be_nil
    end

    it "returns the active sleep record for the user" do
      # Create a finished session first
      SleepRecord.create!(user: user, clock_in: 3.hours.ago, clock_out: 2.hours.ago)

      # Then create the active session
      active_record = SleepRecord.create!(user: user, clock_in: 1.hour.ago, clock_out: nil)

      active = repo.find_active_by_user(user_id: user.id)

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

  describe "#delete" do
    it "deletes the given sleep record" do
      record = SleepRecord.create!(user: user, clock_in: 2.hours.ago, clock_out: 1.hour.ago)

      expect {
        repo.delete(record)
      }.to change { SleepRecord.exists?(record.id) }.from(true).to(false)
    end
  end

  describe "#fanout_to_followers" do
    let(:follower_ids) { [101, 102, 103] }
    let(:sleep_record) do
      SleepRecord.create!(user: user, clock_in: 2.hours.ago, clock_out: 1.hour.ago)
    end

    before do
      stub_const("SleepRecordRepository::FEED_LIST_LIMIT", 2)
      $redis.del("feed:#{follower_ids}")
    end

    it "pushes the sleep record to each follower's feed in Redis" do
      repo.fanout_to_followers(sleep_record, follower_ids)

      follower_ids.each do |fid|
        feed_key = "feed:#{fid}"
        feed = $redis.lrange(feed_key, 0, -1)

        expect(feed.length).to eq(1)
        expect(JSON.parse(feed.first)["id"]).to eq(sleep_record.id)
      end
    end

    it "trims the feed to FEED_LIST_LIMIT items" do
      stub_const("FEED_LIST_LIMIT", 2) # override for test
      3.times do |i|
        sr = SleepRecord.create!(user: user, clock_in: (2 + i).hours.ago, clock_out: i.hours.ago)
        repo.fanout_to_followers(sr, follower_ids)
      end

      follower_ids.each do |fid|
        feed_key = "feed:#{fid}"
        feed = $redis.lrange(feed_key, 0, -1)
        expect(feed.length).to eq(2) # should be trimmed to limit
      end
    end
  end
end
