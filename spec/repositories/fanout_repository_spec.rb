require 'rails_helper'

RSpec.describe FanoutRepository do
  let(:repo) { described_class.new }
  let(:user) { User.create!(name: "Alice") }
  let(:follower_ids) { [101, 102, 103] }

  before do
    SleepRecord.delete_all
    stub_const("Repository::FEED_LIST_LIMIT", 2)
    stub_const("Repository::FEED_TTL_SECONDS", 3600)
    follower_ids.each { |fid| $redis.del("feed:#{fid}") }
  end

  def create_sleep_record(offset_hours)
    SleepRecord.create!(
      user: user,
      clock_in: offset_hours.hours.ago,
      clock_out: (offset_hours - 1).hours.ago
    )
  end

  describe "#write_fanout" do
    let(:sleep_record) { create_sleep_record(2) }

    it "adds the sleep record to each follower's feed with correct score" do
      repo.write_fanout(sleep_record: sleep_record, follower_ids: follower_ids)

      follower_ids.each do |fid|
        feed_key = "feed:#{fid}"
        members = $redis.zrange(feed_key, 0, -1, with_scores: true)

        expect(members.length).to eq(1)
        member, score = members.first
        expect(member.to_i).to eq(sleep_record.id)
        expect(score.to_i).to eq(sleep_record.sleep_time.to_i)
        expect($redis.ttl(feed_key)).to be > 0
      end
    end

    it "trims the feed to FEED_LIST_LIMIT most recent items" do
      records = [3, 2, 1].map { |h| create_sleep_record(h) }
      records.each { |sr| repo.write_fanout(sleep_record: sr, follower_ids: follower_ids) }

      follower_ids.each do |fid|
        feed = $redis.zrevrange("feed:#{fid}", 0, -1).map(&:to_i)
        expected = records.sort_by(&:clock_in).reverse.first(2).map(&:id)
        expect(feed).to eq(expected)
      end
    end

    it "does not add duplicate sleep record to feed" do
      repo.write_fanout(sleep_record: sleep_record, follower_ids: follower_ids)
      repo.write_fanout(sleep_record: sleep_record, follower_ids: follower_ids)

      follower_ids.each do |fid|
        feed = $redis.zrange("feed:#{fid}", 0, -1)
        expect(feed.count { |id| id.to_i == sleep_record.id }).to eq(1)
      end
    end

    it "resets TTL on each addition" do
      repo.write_fanout(sleep_record: sleep_record, follower_ids: [follower_ids[0]])
      sleep(2)
      ttl_1 = $redis.ttl("feed:#{follower_ids[0]}")

      new_record = SleepRecord.create!(user: user, clock_in: 1.hour.ago, clock_out: Time.now)
      repo.write_fanout(sleep_record: new_record, follower_ids: [follower_ids[1]])
      ttl_2 = $redis.ttl("feed:#{follower_ids[1]}")

      expect(ttl_2).to be > ttl_1
    end
  end

  describe "#list_fanout" do
    let(:user_id) { follower_ids.first }
    let(:feed_key) { "feed:#{user_id}" }
    let(:sleep_records) { [3, 2, 1].map { |h| create_sleep_record(h) } }

    before do
      $redis.del(feed_key)
      sleep_records.each { |sr| $redis.zadd(feed_key, sr.clock_in.to_i, sr.id) }
    end

    it "returns sleep record ids in descending order by clock_in" do
      ids = repo.list_fanout(user_id: user_id, limit: 2)
      expected = sleep_records.sort_by(&:clock_in).reverse.first(2).map(&:id)
      expect(ids).to eq(expected)
    end

    it "returns items older than cursor when provided" do
      sorted = sleep_records.sort_by(&:clock_in).reverse
      cursor = sorted.first.clock_in.to_i
      ids = repo.list_fanout(user_id: user_id, cursor: cursor, limit: 2)
      expected = sorted.drop(1).first(2).map(&:id)
      expect(ids).to eq(expected)
    end

    it "returns an empty array when cache is empty" do
      $redis.del(feed_key)
      ids = repo.list_fanout(user_id: user_id, limit: 2)
      expect(ids).to eq([])
    end
  end
end
