class TargetUrl < ApplicationRecord
  has_many :short_urls, dependent: :destroy
  has_many :visits, through: :short_urls

  validates :url, presence: true
  validate :url_must_be_valid

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
end
