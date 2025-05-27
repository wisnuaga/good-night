module Cache
  class BaseCache
    def initialize(prefix:, ttl:)
      @prefix = prefix
      @ttl = ttl
    end

    def key(id)
      "#{@prefix}:#{id}"
    end

    # ---- GET ----
    def get(id)
      raw = $redis.get(key(id))
      raw ? deserialize(raw) : nil
    end

    def get_many(ids)
      keys = ids.map { |id| key(id) }
      values = $redis.mget(*keys)

      found = []
      missed_ids = []

      values.each_with_index do |val, index|
        if val
          found << deserialize(val)
        else
          missed_ids << ids[index]
        end
      end

      [found, missed_ids]
    end

    # ---- SET ----
    def set(record)
      $redis.setex(key(record.id), @ttl, serialize(record))
    end

    def set_many(records)
      records.each { |record| set(record) }
    end

    # ---- DELETE (Optional) ----
    def delete(id)
      $redis.del(key(id))
    end

    def delete_many(ids)
      keys = ids.map { |id| key(id) }
      $redis.del(*keys)
    end

    private

    # Override if needed
    def serialize(record)
      record.to_json
    end

    def deserialize(json)
      JSON.parse(json)
    end
  end
end
