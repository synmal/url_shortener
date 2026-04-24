class ShortUrl < ApplicationRecord
  belongs_to :target_url
  has_many :visits, dependent: :destroy

  # Uses Base58 alphabet (excludes 0/O/l/I to avoid ambiguity). Slugs are generated at the service layer.
  # The regex enforces this format and length constraint at the model level, catching invalid input before routing.
  BASE58_SLUG = /\A[1-9A-HJ-NP-Za-km-z]{4,15}\z/

  validates :slug, presence: true, uniqueness: { case_sensitive: true },
                    format: { with: BASE58_SLUG, message: "must be 4-15 Base58 characters" }

  # Prevents external code from directly setting visits_count, which must only be modified
  # through increment_visits! to maintain the counter invariant.
  attr_readonly :visits_count

  # Uses SQL-level atomic increment via update_counters to avoid race conditions
  # under concurrent redirect requests. The class method is required because
  # update_counters is a class-level ActiveRecord method.
  def increment_visits!
    raise ArgumentError, "cannot increment visits on an unsaved record" if id.nil?

    count = self.class.update_counters(id, visits_count: 1)
    raise ActiveRecord::RecordNotFound, "ShortUrl##{id} not found during visits increment" if count.zero?
  end
end
