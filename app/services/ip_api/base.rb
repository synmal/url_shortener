class IpApi::Base
  # ip-api.com free tier only supports HTTP. HTTPS requires a paid Pro API key.
  BASE_URL = ENV.fetch("IP_API_BASE_URL", "http://ip-api.com")

  TIMEOUT = 10

  def self.connection
    Faraday.new(url: BASE_URL) do |f|
      f.options.timeout = TIMEOUT
      f.options.open_timeout = TIMEOUT
    end
  end
end
