module Caches
  class SleepRecordCache < Base
    def initialize
      @ttl = ENV.fetch('SLEEP_RECORD_CACHE_TTL', 6.hours.to_i).to_i
      puts "TTL: #{@ttl}"
      super(prefix: 'cache:sleep_record', ttl: @ttl)
    end

    private

    def deserialize(json)
      return nil unless json.present?

      SleepRecord.new(JSON.parse(json).deep_symbolize_keys)
    rescue JSON::ParserError
      nil
    end
  end
end
