class ShortUrlsController < ApplicationController
  def show
    short_url = ShortUrl.find_by!(slug: params[:slug])

    short_url.visits.create!(ip_address: request.remote_ip, visited_at: Time.current)
    short_url.increment_visits!

    redirect_to short_url.target_url.url, allow_other_host: true, status: :found
  end
end
