Rails.application.routes.draw do
  devise_for :users
  root "target_urls#new"

  get "dashboard", to: "dashboard#index", as: :dashboard

  resources :target_urls, only: [ :new, :create, :show ]

  get "/:slug", to: "short_urls#show", as: :short_url, constraints: { slug: /[1-9A-HJ-NP-Za-km-z]{4,15}/ }
  get "/:slug/metrics", to: "metrics#show", as: :short_url_metrics, constraints: { slug: /[1-9A-HJ-NP-Za-km-z]{4,15}/ }

  get "up" => "rails/health#show", as: :rails_health_check

  require "sidekiq/web"
  Sidekiq::Web.use Rack::Auth::Basic do |username, password|
    ActiveSupport::SecurityUtils.secure_compare(
      username, ENV.fetch("SIDEKIQ_WEB_USERNAME", "admin")
    ) & ActiveSupport::SecurityUtils.secure_compare(
      password, ENV.fetch("SIDEKIQ_WEB_PASSWORD", SecureRandom.hex)
    )
  end
  mount Sidekiq::Web => "/sidekiq"
end
