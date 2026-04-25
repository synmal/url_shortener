class MetricsController < ApplicationController
  before_action :authenticate_user!

  def show
    @short_url = current_user.short_urls.includes(:target_url, :visits).find_by!(slug: params[:slug])
    @visits_by_country = @short_url.visits.group(:country).order(count_all: :desc).count
    @pagy, @recent_visits = pagy(@short_url.visits.order(visited_at: :desc), items: 25)
  end
end
