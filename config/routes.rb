Rails.application.routes.draw do
  root "target_urls#new"
  resources :target_urls, only: [:new, :create]

  get "/:slug", to: "short_urls#show", as: :short_url, constraints: { slug: ShortUrl::BASE58_SLUG }
  get "/:slug/metrics", to: "metrics#show", as: :short_url_metrics, constraints: { slug: ShortUrl::BASE58_SLUG }

  get "up" => "rails/health#show", as: :rails_health_check
end
