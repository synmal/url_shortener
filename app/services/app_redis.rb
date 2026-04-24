require "connection_pool"

module AppRedis
  POOL_SIZE = ENV.fetch("REDIS_POOL_SIZE", 5).to_i
  POOL_TIMEOUT = ENV.fetch("REDIS_POOL_TIMEOUT", 5).to_i # seconds

  @pool = ConnectionPool.new(size: POOL_SIZE, timeout: POOL_TIMEOUT) do
    Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/2"))
  end

  # Yields a Redis connection checked out from the pool.
  # The connection is automatically returned after the block completes.
  def self.with(...)
    @pool.with(...)
  end
end
