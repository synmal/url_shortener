class TargetUrlsController < ApplicationController
  def new
    @form = TargetUrlForm.new
  end

  def create
    @form = TargetUrlForm.new(form_params)

    if @form.valid?
      result = LinkShortenerService.call(@form.url)
      @short_url = result.short_url
      @target_url = @short_url.target_url

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to target_url_path(@short_url.slug), notice: "URL shortened successfully!" }
      end
    else
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace("url_card", partial: "target_urls/form_card", locals: { form: @form }) }
        format.html { render :new, status: :unprocessable_content }
      end
    end
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    message = e.is_a?(ActiveRecord::RecordInvalid) ? e.record.errors.full_messages.to_sentence : e.message
    @form.errors.add(:url, message)

    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.replace("url_card", partial: "target_urls/form_card", locals: { form: @form }) }
      format.html { render :new, status: :unprocessable_content }
    end
  end

  def show
    @short_url = ShortUrl.find_by!(slug: params[:id])
    @target_url = @short_url.target_url
  end

  private

  def form_params
    params.require(:target_url_form).permit(:url)
  end
end
