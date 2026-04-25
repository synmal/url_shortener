FactoryBot.define do
  factory :target_url do
    sequence(:url) { |n| "https://example-#{n}.com" }
    title { nil }
  end
end
