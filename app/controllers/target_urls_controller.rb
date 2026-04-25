class TargetUrlsController < ApplicationController
  def new
    @form = TargetUrlForm.new
  end

  def create
    @form = TargetUrlForm.new(form_params)

    if @form.valid?
      result = LinkShortenerService.call(@form.url)
      @target_url = result.target_url
      @short_url = result.short_url
      render :show
    else
      render :new, status: :unprocessable_content
    end
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    message = e.is_a?(ActiveRecord::RecordInvalid) ? e.record.errors.full_messages.to_sentence : e.message
    @form.errors.add(:url, message)
    render :new, status: :unprocessable_content
  end

  private

  def form_params
    params.require(:target_url_form).permit(:url)
  end
end
