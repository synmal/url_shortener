class IpApi::Batch
  # ip-api.com free tier limit per batch request.
  BATCH_SIZE = 100
  FIELDS = "status,query,lat,lon,country"

  Result = Data.define(:data, :rate_limit_remaining, :rate_limit_ttl, :success?)

  def self.call(ip_addresses)
    raise ArgumentError, "ip_addresses must be an Array" unless ip_addresses.is_a?(Array)
    raise ArgumentError, "ip_addresses cannot exceed #{BATCH_SIZE}" if ip_addresses.size > BATCH_SIZE

    return Result.new(data: [], rate_limit_remaining: 0, rate_limit_ttl: 0, success?: true) if ip_addresses.empty?

    response = IpApi::Base.connection.post("/batch") do |req|
      req.body = ip_addresses.map { |ip| { fields: FIELDS, query: ip } }.to_json
      req.headers["Content-Type"] = "application/json"
    end

    rate_limit_remaining = response.headers["X-Rl"].to_i
    rate_limit_ttl = response.headers["X-Ttl"].to_i

    parsed = JSON.parse(response.body, symbolize_names: true)
    failed_count = parsed.count { |row| row[:status] != "success" }
    Rails.logger.info("[IpApi::Batch] #{failed_count}/#{parsed.size} lookups failed") if failed_count.positive?
    data = parsed.filter_map { |row| row[:status] == "success" ? row : nil }

    # success? reflects the HTTP request status, not individual IP lookups.
    # Individual lookup failures are logged but do not affect success?.
    Result.new(data:, rate_limit_remaining:, rate_limit_ttl:, success?: true)
  rescue Faraday::Error, JSON::ParserError => e
    Rails.logger.error("[IpApi::Batch] Request failed: #{e.message}")
    Result.new(data: [], rate_limit_remaining: 0, rate_limit_ttl: 60, success?: false)
  end
end
