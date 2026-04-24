module AppRedis
  def self.client
    @client ||= Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/2"))
  end
end
