class ApplicationController < ActionController::Base
  include Pagy::Method

  allow_browser versions: :modern
  stale_when_importmap_changes

  rescue_from ActiveRecord::RecordNotFound, with: :not_found

  private

  def not_found(exception)
    Rails.logger.info("[ApplicationController] #{exception.message}")
    head :not_found
  end
end
