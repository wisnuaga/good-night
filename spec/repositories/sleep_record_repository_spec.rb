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

    it "returns sleep records for given user ids ordered by clock_in desc" do
      now = Time.current
      record1 = SleepRecord.create!(user: user, clock_in: now - 2.hours, clock_out: now - 1.hour)
      record2 = SleepRecord.create!(user: user, clock_in: now - 4.hours, clock_out: now - 3.hours)

      records = repo.list_by_user_ids(user_ids: [user.id])

      expect(records).to eq([record1, record2])
    end

    it "returns records for multiple user ids" do
      now = Time.current
      record1 = SleepRecord.create!(user: user, clock_in: now - 2.hours, clock_out: now - 1.hour)
      record2 = SleepRecord.create!(user: user2, clock_in: now - 1.hour, clock_out: now - 0.5.hour)

      records = repo.list_by_user_ids(user_ids: [user.id, user2.id])

      expect(records).to include(record1, record2)
      expect(records.map(&:user_id).uniq.sort).to eq([user.id, user2.id].sort)
    end

    it "applies cursor to return records with clock_in < cursor" do
      record1 = SleepRecord.create!(user: user, clock_in: now - 2.hours, clock_out: now - 3.hours)
      record2 = SleepRecord.create!(user: user, clock_in: now - 4.hours, clock_out: now - 1.hour)

      cursor = now - 3.hours

      records = repo.list_by_user_ids(user_ids: [user.id], cursor: cursor)

      # Expect the first returned record to be record2 (clock_in < cursor)
      expect(records.first.clock_in).to be_within(1.second).of(record2.clock_in)
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

    it "returns records by given ids ordered by clock_in desc" do
      r1 = SleepRecord.create!(user: user, clock_in: 5.hours.ago, clock_out: 4.hours.ago)
      r2 = SleepRecord.create!(user: user, clock_in: 3.hours.ago, clock_out: 2.hours.ago)
      result = repo.list_by_ids(ids: [r1.id, r2.id])
      expect(result).to eq([r2, r1])
    end

    it "applies cursor correctly" do
      r1 = SleepRecord.create!(user: user, clock_in: 5.hours.ago, clock_out: 4.hours.ago)
      r2 = SleepRecord.create!(user: user, clock_in: 3.hours.ago, clock_out: 2.hours.ago)
      cursor = 4.hours.ago
      result = repo.list_by_ids(ids: [r1.id, r2.id], cursor: cursor)
      expect(result).to eq([r1])
    end
  end

  describe "#count_by_user_ids" do
    let(:user) { create(:user) }

    it "counts records after given clock_in time" do
      SleepRecord.create!(user: user, clock_in: 5.hours.ago, clock_out: 4.hour)
      count = repo.count_by_user_ids(user_ids: [user.id], clock_in: 1.day.ago)
      expect(count).to eq(1)
    end

    it "returns 0 if no records match" do
      count = repo.count_by_user_ids(user_ids: [user.id], clock_in: Time.current)
      expect(count).to eq(0)
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
      stub_const("SleepRecordRepository::FEED_TTL_SECONDS", 3600)
      follower_ids.each { |fid| $redis.del("feed:#{fid}") }
    end

    it "adds the sleep record to each follower's sorted set feed with correct score" do
      repo.fanout_to_followers(sleep_record: sleep_record, follower_ids: follower_ids)

      follower_ids.each do |fid|
        feed_key = "feed:#{fid}"
        # Fetch all members with scores from sorted set
        members_with_scores = $redis.zrange(feed_key, 0, -1, with_scores: true)

        # There should be exactly one member, the sleep_record.id with score = clock_in.to_i
        expect(members_with_scores.length).to eq(1)
        member, score = members_with_scores.first
        expect(member.to_i).to eq(sleep_record.id)
        expect(score.to_i).to eq(sleep_record.clock_in.to_i)

        # Check TTL is set (greater than 0)
        ttl = $redis.ttl(feed_key)
        expect(ttl).to be > 0
      end
    end

    it "trims the sorted set feed to FEED_LIST_LIMIT most recent items" do
      # Create 3 sleep records with increasing clock_in times
      records = 3.times.map do |i|
        SleepRecord.create!(user: user, clock_in: (3 - i).hours.ago, clock_out: (2 - i).hours.ago)
      end

      records.each do |sr|
        repo.fanout_to_followers(sleep_record: sr, follower_ids: follower_ids)
      end

      follower_ids.each do |fid|
        feed_key = "feed:#{fid}"
        # zrevrange returns highest score first (most recent clock_in)
        feed = $redis.zrevrange(feed_key, 0, -1).map(&:to_i)

        # The feed should be trimmed to FEED_LIST_LIMIT (2)
        expect(feed.length).to eq(2)

        # It should contain the 2 most recent sleep record IDs by clock_in
        expected_ids = records.sort_by(&:clock_in).reverse.first(2).map(&:id)
        expect(feed).to eq(expected_ids)
      end
    end
  end

  describe "#list_fanout" do
    let(:user_id) { 101 }
    let(:feed_key) { "feed:#{user_id}" }
    let(:sleep_records) do
      3.times.map do |i|
        SleepRecord.create!(user: user, clock_in: (3 - i).hours.ago, clock_out: (2 - i).hours.ago)
      end
    end

    before do
      $redis.del(feed_key)
      sleep_records.each do |sr|
        $redis.zadd(feed_key, sr.clock_in.to_i, sr.id)
      end
    end

    it "returns sleep record ids from Redis sorted set in descending order by clock_in" do
      ids = repo.list_fanout(user_id: user_id, limit: 2)
      expected_ids = sleep_records.sort_by(&:clock_in).reverse.first(2).map(&:id)
      expect(ids).to eq(expected_ids)
    end

    context "when cache returns empty list" do
      before do
        $redis.del(feed_key)  # ensure cache is empty
      end

      it "returns an empty array" do
        ids = repo.list_fanout(user_id: user_id, limit: 2)
        expect(ids).to eq([])
      end
    end
  end
end
