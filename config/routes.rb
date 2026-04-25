Rails.application.routes.draw do
  devise_for :users
  root "target_urls#new"

  get "dashboard", to: "dashboard#index", as: :dashboard

  resources :target_urls, only: [ :new, :create, :show ]

  get "/:slug", to: "short_urls#show", as: :short_url, constraints: { slug: /[1-9A-HJ-NP-Za-km-z]{4,15}/ }
  get "/:slug/metrics", to: "metrics#show", as: :short_url_metrics, constraints: { slug: /[1-9A-HJ-NP-Za-km-z]{4,15}/ }

  get "up" => "rails/health#show", as: :rails_health_check

  require "sidekiq/web"
  mount Sidekiq::Web => "/sidekiq", constraints: ->(req) {
    authenticated = Rack::BasicAuth::Request.new(req.env).provided? &&
      Rack::BasicAuth::Request.new(req.env).basic? &&
      Rack::BasicAuth::Request.new(req.env).credentials &&
      Rack::BasicAuth::Request.new(req.env).credentials == [
        ENV.fetch("SIDEKIQ_WEB_USERNAME", "admin"),
        ENV.fetch("SIDEKIQ_WEB_PASSWORD", SecureRandom.hex)
      ]

    unless authenticated
      Rack::BasicAuth::Request.new(req.env).challenge("Sidekiq")
    end

    authenticated
  }
end
