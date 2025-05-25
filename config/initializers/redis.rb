redis_connection = Rails.env.test? ? MockRedis.new : Redis.new(host: ENV['REDIS_HOST'], db: ENV['REDIS_DB'].to_i, port: ENV['REDIS_PORT'].to_i)

$redis = Redis::Namespace.new(:good_night, redis: redis_connection)
