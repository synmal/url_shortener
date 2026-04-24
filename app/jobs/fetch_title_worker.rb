class FetchTitleWorker < ApplicationJob
  queue_as :default

  def perform(target_url_id)
    target_url = TargetUrl.find_by(id: target_url_id)
    if target_url.nil?
      Rails.logger.info("[FetchTitleWorker] TargetUrl##{target_url_id} not found, skipping")
      return
    end
    return if target_url.title.present?

    title = TitleFetcherService.call(target_url.url)
    target_url.update(title:) if title
  end
end
