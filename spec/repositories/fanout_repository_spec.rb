require 'rails_helper'

RSpec.describe FanoutRepository do
  let(:redis) { instance_double('Redis') }
  let(:repo) { described_class.new }
  let(:user_id) { 123 }
  let(:follower_ids) { [1, 2, 3] }
  let(:sleep_record) { double('SleepRecord', id: 99, sleep_time: 3600.5) }
  let(:feed_key) { "feed:#{user_id}" }

  before do
    $redis = redis
    stub_const('Repository::FEED_LIST_LIMIT', 5)
    stub_const('Repository::FEED_TTL_SECONDS', 86_400)
  end

  describe '#write_fanout' do
    it 'adds the sleep record to each follower feed' do
      follower_ids.each do |fid|
        expect(repo).to receive(:add_to_feed).with(user_id: fid, sleep_record: sleep_record)
      end

      repo.write_fanout(sleep_record: sleep_record, follower_ids: follower_ids)
    end
  end

  describe '#list_fanout' do
    context 'when cursor is provided' do
      it 'calls zrevrangebyscore with float cursor and maps to integers' do
        float_cursor = 3600.4
        redis_result = ['88', '77']

        expect(redis).to receive(:zrevrangebyscore)
                           .with(feed_key, "(#{float_cursor}", "-inf", limit: [0, Repository::FEED_LIST_LIMIT])
                           .and_return(redis_result)

        result = repo.list_fanout(user_id: user_id, cursor: float_cursor, limit: Repository::FEED_LIST_LIMIT)
        expect(result).to eq([88, 77])
      end
    end

    context 'when cursor is nil' do
      it 'calls zrevrange and maps to integers' do
        redis_result = ['55', '44']
        expect(redis).to receive(:zrevrange).with(feed_key, 0, Repository::FEED_LIST_LIMIT - 1).and_return(redis_result)

        result = repo.list_fanout(user_id: user_id, cursor: nil, limit: Repository::FEED_LIST_LIMIT)
        expect(result).to eq([55, 44])
      end
    end
  end

  describe '#remove_from_feed' do
    it 'removes given sleep record ids from Redis' do
      ids = [11, 22]
      ids.each do |id|
        expect(redis).to receive(:zrem).with(feed_key, id)
      end

      repo.remove_from_feed(user_id: user_id, sleep_record_ids: ids)
    end
  end

  describe '#add_to_feed' do
    it 'adds sleep_record to the Redis sorted set with correct score and trims the feed' do
      expect(redis).to receive(:zadd).with(feed_key, [sleep_record.sleep_time, sleep_record.id], nx: true)
      expect(repo).to receive(:trim_feed).with(user_id)

      repo.add_to_feed(user_id: user_id, sleep_record: sleep_record)
    end
  end

  describe '#trim_feed' do
    it 'trims the sorted set and sets an expiry' do
      expect(redis).to receive(:zremrangebyrank).with(feed_key, 0, -(Repository::FANOUT_LIMIT + 1))
      expect(redis).to receive(:expire).with(feed_key, Repository::FEED_TTL_SECONDS)

      repo.trim_feed(user_id)
    end
  end
end
