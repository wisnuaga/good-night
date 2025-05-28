require 'rails_helper'

RSpec.describe Caches::SleepRecordCache do
  let(:redis) { instance_double('Redis') }
  let(:default_ttl) { 6.hours.to_i }
  let(:env_ttl) { 10_000 }
  let(:cache) { described_class.new }

  before do
    $redis = redis
    allow(SleepRecord).to receive(:new).and_call_original # if you want actual instantiation
  end

  describe '#initialize' do
    it 'loads TTL from ENV or defaults' do
      ClimateControl.modify SLEEP_RECORD_CACHE_TTL: env_ttl.to_s do
        cache_with_env = described_class.new
        expect(cache_with_env.instance_variable_get(:@ttl)).to eq(env_ttl)
      end

      ClimateControl.modify SLEEP_RECORD_CACHE_TTL: nil do
        cache_default = described_class.new
        expect(cache_default.instance_variable_get(:@ttl)).to eq(default_ttl)
      end
    end
  end

  describe '#deserialize' do
    let(:valid_json) { '{"id":1,"user_id":2,"clock_in":"2025-05-28T00:00:00Z"}' }
    let(:invalid_json) { 'invalid json' }
    let(:empty_json) { '' }
    let(:nil_json) { nil }

    it 'returns SleepRecord object for valid JSON' do
      expect(SleepRecord).to receive(:new).with(
        a_hash_including(:id, :user_id, :clock_in)
      ).and_call_original

      obj = cache.send(:deserialize, valid_json)
      expect(obj).to be_a(SleepRecord)
      expect(obj.id).to eq(1)
    end

    it 'returns nil for invalid JSON' do
      expect(cache.send(:deserialize, invalid_json)).to be_nil
    end

    it 'returns nil for empty JSON' do
      expect(cache.send(:deserialize, empty_json)).to be_nil
    end

    it 'returns nil for nil JSON' do
      expect(cache.send(:deserialize, nil_json)).to be_nil
    end
  end
end
