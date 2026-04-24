FactoryBot.define do
  factory :visit do
    association :short_url
    ip_address { "192.168.1.1" }
    visited_at { Time.current }
    processed_at { nil }
  end
end
