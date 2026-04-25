class ApplicationController < ActionController::Base
  include Pagy::Method

  allow_browser versions: :modern
  stale_when_importmap_changes

  rescue_from ActiveRecord::RecordNotFound, with: :not_found

  def after_sign_in_path_for(_resource)
    root_path
  end

  private

  def not_found(exception)
    Rails.logger.info("[ApplicationController] #{exception.message}")
    head :not_found
  end
end
