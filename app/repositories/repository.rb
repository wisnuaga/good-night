class Repository
  FEED_LIST_LIMIT = (ENV['FEED_LIST_LIMIT'] || 50).to_i
  FEED_TTL_SECONDS = (ENV['FEED_TTL_SECONDS'] || 604_800).to_i  # 7 days
  FANOUT_LIMIT = (ENV['SLEEP_RECORD_FANOUT_LIMIT'] || 1000).to_i

  # Use a method so that the cutoff is always relative to current time
  def feed_since_limit
    FEED_TTL_SECONDS.seconds.ago
  end
end