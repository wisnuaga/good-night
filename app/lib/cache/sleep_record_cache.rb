module Cache
  class SleepRecordCache < Base
    def initialize
      super(prefix: 'cache:sleep_record', ttl: 6.hours)
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