class DashboardController < ApplicationController
  before_action :authenticate_user!

  def index
    @pagy, @short_urls = pagy(current_user.short_urls.includes(:target_url).order(created_at: :desc), items: 20)
  end
end
