FactoryBot.define do
  factory :short_url do
    slug { SecureRandom.base58(15) }
    association :target_url
  end
end
