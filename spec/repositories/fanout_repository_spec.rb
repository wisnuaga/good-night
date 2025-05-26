require 'rails_helper'

RSpec.describe FanoutRepository do
  let(:repo) { described_class.new }
  let(:user) { User.create!(name: "Alice") }

  before do
    SleepRecord.delete_all
  end

  describe "#write_fanout" do
    let(:follower_ids) { [101, 102, 103] }
    let(:sleep_record) do
      SleepRecord.create!(user: user, clock_in: 2.hours.ago, clock_out: 1.hour.ago)
    end

    before do
      stub_const("Repository::FEED_LIST_LIMIT", 2)
      stub_const("Repository::FEED_TTL_SECONDS", 3600)
      follower_ids.each { |fid| $redis.del("feed:#{fid}") }
    end

    it "adds the sleep record to each follower's sorted set feed with correct score" do
      repo.write_fanout(sleep_record: sleep_record, follower_ids: follower_ids)

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
        repo.write_fanout(sleep_record: sr, follower_ids: follower_ids)
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
