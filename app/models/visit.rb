class Visit < ApplicationRecord
  belongs_to :short_url

  validates :ip_address, presence: true, format: { with: /\A(\d{1,3}\.){3}\d{1,3}\z/, message: "must be a valid IPv4 address" }
  validates :visited_at, presence: true

  # Geo fields are populated asynchronously after visit creation.
  # Coordinate range validation prevents corrupt analytics data from malformed API responses.
  validates :latitude, numericality: { greater_than_or_equal_to: -90, less_than_or_equal_to: 90, allow_nil: true }
  validates :longitude, numericality: { greater_than_or_equal_to: -180, less_than_or_equal_to: 180, allow_nil: true }

  scope :unprocessed, -> { where(processed_at: nil) }
end
