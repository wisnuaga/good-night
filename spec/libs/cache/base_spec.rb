require 'rails_helper'

RSpec.describe Caches::Base do
  let(:redis) { instance_double('Redis') }
  let(:prefix) { 'cache:test' }
  let(:ttl) { 3600 }
  let(:cache) { described_class.new(prefix: prefix, ttl: ttl) }

  let(:record) { double('Record', id: 1, to_json: '{"id":1,"name":"foo"}') }
  let(:record2) { double('Record', id: 2, to_json: '{"id":2,"name":"bar"}') }

  before do
    # Mock global $redis
    $redis = redis
  end

  describe '#key' do
    it 'returns correct redis key' do
      expect(cache.key(123)).to eq("#{prefix}:123")
    end
  end

  describe '#get' do
    it 'returns deserialized object if cache hit' do
      json = '{"id":1,"name":"foo"}'
      expect($redis).to receive(:get).with("#{prefix}:1").and_return(json)
      expect(cache.get(1)).to eq(JSON.parse(json))
    end

    it 'returns nil if cache miss' do
      expect($redis).to receive(:get).with("#{prefix}:999").and_return(nil)
      expect(cache.get(999)).to be_nil
    end
  end

  describe '#get_many' do
    it 'returns found objects and missed ids correctly' do
      keys = ["#{prefix}:1", "#{prefix}:2", "#{prefix}:3"]
      json1 = '{"id":1,"name":"foo"}'
      json3 = '{"id":3,"name":"baz"}'

      expect($redis).to receive(:mget).with(*keys).and_return([json1, nil, json3])

      found, missed = cache.get_many([1, 2, 3])

      expect(found).to eq([JSON.parse(json1), JSON.parse(json3)])
      expect(missed).to eq([2])
    end
  end

  describe '#set' do
    it 'sets cache with key, ttl, and serialized record' do
      expect($redis).to receive(:setex).with("#{prefix}:1", ttl, record.to_json)
      cache.set(record)
    end
  end

  describe '#set_many' do
    it 'calls set for each record' do
      expect(cache).to receive(:set).with(record).ordered
      expect(cache).to receive(:set).with(record2).ordered
      cache.set_many([record, record2])
    end
  end

  describe '#delete' do
    it 'deletes key from redis' do
      expect($redis).to receive(:del).with("#{prefix}:1")
      cache.delete(1)
    end
  end

  describe '#delete_many' do
    it 'deletes multiple keys from redis' do
      keys = ["#{prefix}:1", "#{prefix}:2", "#{prefix}:3"]
      expect($redis).to receive(:del).with(*keys)
      cache.delete_many([1, 2, 3])
    end
  end

  describe '#serialize' do
    it 'serializes record to JSON' do
      expect(cache.send(:serialize, record)).to eq(record.to_json)
    end
  end

  describe '#deserialize' do
    it 'deserializes JSON string to hash' do
      json = '{"id":1,"name":"foo"}'
      expect(cache.send(:deserialize, json)).to eq({"id" => 1, "name" => "foo"})
    end
  end
end
