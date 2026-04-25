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
    if title
      target_url.update(title:)
      broadcast_title_update(target_url)
    end
  end

  private

  # Broadcast is best-effort — if it fails, the DB already has the title,
  # so a page refresh will show it. Wrapping separately prevents a broadcast
  # failure from re-enqueuing the job (which would skip the update since title is now present).
  def broadcast_title_update(target_url)
    Turbo::StreamsChannel.broadcast_update_to(
      "target_url_#{target_url.id}",
      target: "page_title",
      partial: "target_urls/title",
      locals: { target_url: }
    )
  rescue StandardError => e
    Rails.logger.warn("[FetchTitleWorker] Broadcast failed for TargetUrl##{target_url.id}: #{e.message}")
  end
end
