class BatchProcessVisitsWorker < ApplicationJob
  queue_as :low
  RATE_LIMIT_KEY = "ip_api:rate_limit_remaining"

  def perform
    return if rate_limited?

    visits = Visit.unprocessed.limit(IpApi::Batch::BATCH_SIZE)
    return if visits.empty?

    ip_addresses = visits.map(&:ip_address).uniq
    result = IpApi::Batch.call(ip_addresses)

    # Persist rate limit before raising so retry respects the TTL.
    persist_rate_limit(result.rate_limit_remaining, result.rate_limit_ttl)

    unless result.success?
      raise "IpApi::Batch request failed (remaining: #{result.rate_limit_remaining}, ttl: #{result.rate_limit_ttl})"
    end

    enrich_visits(visits, result.data)

    if Visit.unprocessed.exists?
      BatchProcessVisitsWorker.set(wait: 30.seconds).perform_later
    end
  rescue Redis::BaseError => e
    Rails.logger.error("[BatchProcessVisitsWorker] Redis error: #{e.message}")
    raise
  end

  private

  def rate_limited?
    remaining = AppRedis.with { |conn| conn.get(RATE_LIMIT_KEY) }&.to_i
    return false if remaining.nil?

    if remaining <= 0
      Rails.logger.info("[BatchProcessVisitsWorker] Rate limited — skipping")
      true
    else
      false
    end
  rescue Redis::BaseError => e
    # Fail-open: proceed without rate limiting so visits still get processed
    Rails.logger.warn("[BatchProcessVisitsWorker] Redis error during rate limit check: #{e.message}")
    false
  end

  def persist_rate_limit(remaining, ttl)
    return unless ttl.positive?

    AppRedis.with { |conn| conn.set(RATE_LIMIT_KEY, remaining, ex: ttl) }
  end

  def enrich_visits(visits, geo_data)
    geo_by_ip = geo_data.index_by { |row| row[:query] }
    unenriched_ips = []

    visits.each do |visit|
      data = geo_by_ip[visit.ip_address]

      if data
        unless visit.update(
          latitude: data[:lat],
          longitude: data[:lon],
          country: data[:country],
          processed_at: Time.current
        )
          Rails.logger.warn("[BatchProcessVisitsWorker] Validation failed for Visit##{visit.id}: #{visit.errors.full_messages}")
          # Fallback: clear malformed geo data and mark processed to prevent infinite reprocessing.
          visit.assign_attributes(latitude: nil, longitude: nil, country: nil)
          visit.save(validate: false)
        end
      else
        unenriched_ips << visit.ip_address
        visit.update(processed_at: Time.current)
      end
    end

    if unenriched_ips.any?
      Rails.logger.info("[BatchProcessVisitsWorker] #{unenriched_ips.size} visits had no geo data: #{unenriched_ips.take(5).join(', ')}")
    end
  end
end
