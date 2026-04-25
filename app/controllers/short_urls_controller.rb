class ShortUrlsController < ApplicationController
  def show
    short_url = ShortUrl.find_by!(slug: params[:slug])

    begin
      # Visit tracking is best-effort — failures must not block the redirect.
      ApplicationRecord.transaction do
        short_url.visits.create!(ip_address: request.remote_ip, visited_at: Time.current)
        short_url.increment_visits!
      end
    rescue ActiveRecord::RecordInvalid, ActiveRecord::StatementInvalid => e
      Rails.logger.warn("[ShortUrlsController] Visit tracking failed: #{e.message}")
    end

    redirect_to short_url.target_url.url, allow_other_host: true, status: :found
  end
end
