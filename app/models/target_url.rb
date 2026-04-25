class TargetUrl < ApplicationRecord
  has_many :short_urls, dependent: :destroy
  has_many :visits, through: :short_urls

  validates :url, presence: true
  validate :url_must_be_valid
  validate :url_must_not_resolve_to_private_ip
  validate :url_must_not_be_self_referencing

  # IP ranges that must not be targeted — prevents SSRF to cloud metadata, loopback, link-local,
  # carrier-grade NAT, and IPv4-mapped IPv6 addresses.
  PRIVATE_IPS = [
    IPAddr.new("0.0.0.0/8"),
    IPAddr.new("10.0.0.0/8"),
    IPAddr.new("100.64.0.0/10"),
    IPAddr.new("127.0.0.0/8"),
    IPAddr.new("169.254.0.0/16"),
    IPAddr.new("172.16.0.0/12"),
    IPAddr.new("192.0.0.0/24"),
    IPAddr.new("192.168.0.0/16"),
    IPAddr.new("198.18.0.0/15"),
    IPAddr.new("::1/128"),
    IPAddr.new("::ffff:0:0/96"),
    IPAddr.new("fc00::/7"),
    IPAddr.new("fe80::/10")
  ].freeze

  private

  # URI::DEFAULT_PARSER.make_regexp accepts malformed URLs like http:// (no host) or http://? (query-only).
  # Using URI.parse with explicit host check ensures only well-formed URLs with a valid host are stored,
  # preventing broken redirects.
  def url_must_be_valid
    return if url.blank?

    begin
      uri = URI.parse(url)
      unless %w[http https].include?(uri.scheme) && uri.host.present?
        errors.add(:url, "must be a valid HTTP or HTTPS URL with a host")
      end
    rescue URI::Error, ArgumentError
      errors.add(:url, "is not a valid URL")
    end
  end

  # Rejects URLs pointing to the app's own domain (including subdomains) to prevent redirect chains.
  # APP_HOST should be a bare hostname (no port or scheme), e.g. "short.example.com".
  # If APP_HOST includes a port or scheme, the comparison silently never matches.
  def url_must_not_be_self_referencing
    return if url.blank?
    return if errors[:url].any? # skip if url_must_be_valid already failed

    app_host = ENV["APP_HOST"]
    if app_host.blank?
      Rails.logger.warn("[TargetUrl] APP_HOST not set — self-referencing URL check skipped")
      return
    end

    begin
      uri = URI.parse(url)
      host = uri.host&.downcase
      return unless host == app_host.downcase || host&.end_with?(".#{app_host.downcase}")

      errors.add(:url, "cannot point to this application")
    rescue URI::Error
      # Let url_must_be_valid handle invalid URIs
    end
  end

  # Blocks URLs pointing to private, loopback, or link-local IP addresses to prevent SSRF attacks.
  # Checks literal IPs, well-known hostnames, and DNS-resolved addresses.
  def url_must_not_resolve_to_private_ip
    return if url.blank?
    return if errors[:url].any? # skip if url_must_be_valid already failed

    begin
      uri = URI.parse(url)
      return unless uri.host.present?

      if %w[localhost localhost.localdomain].include?(uri.host.downcase)
        errors.add(:url, "must not resolve to a private or reserved IP address")
        return
      end

      ip = begin
        IPAddr.new(uri.host)
      rescue IPAddr::InvalidAddressError
        nil
      end
      if ip && PRIVATE_IPS.any? { |range| range.include?(ip) }
        errors.add(:url, "must not resolve to a private or reserved IP address")
        return
      end

      resolved = Resolv.getaddresses(uri.host)
      if resolved.any? { |addr| PRIVATE_IPS.any? { |range| range.include?(IPAddr.new(addr)) } }
        errors.add(:url, "must not resolve to a private or reserved IP address")
      end
    rescue Resolv::ResolvError
      Rails.logger.warn("[TargetUrl] DNS resolution failed for #{uri.host}")

      # Unresolvable hostname — let the redirect fail at fetch time
    end
  end
end
