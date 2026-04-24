class LinkShortenerService
  Result = Data.define(:target_url, :short_url)

  # With 58^4 = 11M possible slugs (minimum length), collisions are extremely unlikely.
  # 3 retries is a safety net for the near-impossible case of a random collision.
  MAX_SLUG_RETRIES = 3

  def self.call(url_string)
    new(url_string).call
  end

  def initialize(url_string)
    @url_string = url_string.to_s.strip
  end

  def call
    raise ArgumentError, "URL cannot be blank" if @url_string.blank?

    uri = URI.parse(@url_string)
    raise ArgumentError, "Invalid URL format" unless %w[http https].include?(uri.scheme) && uri.host.present?

    normalized_url = normalize_url(uri)

    ApplicationRecord.transaction do
      target_url = TargetUrl.find_or_create_by!(url: normalized_url)
      short_url = create_short_url(target_url)
      Result.new(target_url:, short_url:)
    end
  rescue URI::Error, ArgumentError => e
    raise ArgumentError, e.message
  end

  private

  # Strips fragments and normalizes scheme/host to lowercase to prevent duplicate TargetUrl rows
  # (e.g., HTTPS://EXAMPLE.COM vs https://example.com).
  def normalize_url(uri)
    uri.fragment = nil
    uri.scheme = uri.scheme.downcase
    uri.host = uri.host.downcase
    uri.to_s
  end

  def create_short_url(target_url)
    MAX_SLUG_RETRIES.times do
      slug = Base58Service.generate
      short_url = target_url.short_urls.build(slug:)
      short_url.save!
      return short_url
    rescue ActiveRecord::RecordNotUnique
      next
    rescue ActiveRecord::RecordInvalid => e
      raise unless e.record.errors[:slug].any?
      next
    end

    raise ArgumentError, "Failed to generate unique slug after #{MAX_SLUG_RETRIES} attempts"
  end
end
