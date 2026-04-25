require "rails_helper"

RSpec.describe TargetUrlsController, type: :controller do
  render_views

  describe "GET #new" do
    it "returns http success" do
      get :new
      expect(response).to have_http_status(:success)
    end

    it "assigns a new TargetUrlForm" do
      get :new
      expect(assigns(:form)).to be_a(TargetUrlForm)
    end
  end

  describe "POST #create" do
    context "with valid URL (turbo_stream)" do
      it "creates a short URL and returns turbo_stream response" do
        post :create, params: { target_url_form: { url: "https://example.com" } }, as: :turbo_stream

        expect(response).to have_http_status(:success)
        expect(assigns(:short_url)).to be_persisted
        expect(assigns(:target_url)).to be_persisted
        expect(assigns(:target_url).url).to eq("https://example.com")
      end

      it "enqueues FetchTitleWorker" do
        expect {
          post :create, params: { target_url_form: { url: "https://example.com" } }, as: :turbo_stream
        }.to have_enqueued_job(FetchTitleWorker)
      end

      it "does not enqueue FetchTitleWorker when title already exists" do
        target_url = create(:target_url, url: "https://example.com", title: "Example")
        create(:short_url, target_url: target_url)

        # LinkShortenerService reuses the existing target_url
        expect {
          post :create, params: { target_url_form: { url: "https://example.com" } }, as: :turbo_stream
        }.not_to have_enqueued_job(FetchTitleWorker)
      end
    end

    context "with valid URL (HTML)" do
      it "redirects to the show page" do
        post :create, params: { target_url_form: { url: "https://example.com" } }

        expect(response).to redirect_to(target_url_path(assigns(:short_url).slug))
      end
    end

    # Turbo Stream always responds with HTTP 200 regardless of the underlying status.
    # The content type is text/vnd.turbo-stream.html and the browser processes the
    # embedded <turbo-stream> actions to update the DOM. A non-200 status would
    # prevent Turbo from processing the response, so Rails normalizes it to :ok.
    # This is why all turbo_stream expectations below use :success instead of
    # :unprocessable_content, even though the controller renders error partials.
    context "with invalid URL (turbo_stream)" do
      it "renders form card replacement with errors" do
        post :create, params: { target_url_form: { url: "invalid-url" } }, as: :turbo_stream

        expect(response).to have_http_status(:success)
        expect(assigns(:form).errors[:url]).to be_present
      end
    end

    context "with invalid URL (HTML)" do
      it "returns unprocessable entity" do
        post :create, params: { target_url_form: { url: "invalid-url" } }

        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context "with blank URL" do
      it "renders form card replacement with errors" do
        post :create, params: { target_url_form: { url: "" } }, as: :turbo_stream

        expect(response).to have_http_status(:success)
        expect(assigns(:form).errors[:url]).to be_present
      end
    end

    context "when LinkShortenerService raises" do
      it "handles ArgumentError and renders form card replacement" do
        allow(LinkShortenerService).to receive(:call).and_raise(ArgumentError, "Invalid URL format")

        post :create, params: { target_url_form: { url: "https://example.com" } }, as: :turbo_stream

        expect(response).to have_http_status(:success)
        expect(assigns(:form).errors[:url]).to include("Invalid URL format")
      end

      it "handles RecordInvalid and renders form card replacement" do
        allow(LinkShortenerService).to receive(:call).and_raise(
          ActiveRecord::RecordInvalid.new(create(:short_url))
        )

        post :create, params: { target_url_form: { url: "https://example.com" } }, as: :turbo_stream

        expect(response).to have_http_status(:success)
        expect(assigns(:form).errors[:url]).to be_present
      end
    end
  end

  describe "GET #show" do
    it "returns http success" do
      short_url = create(:short_url)

      get :show, params: { id: short_url.slug }

      expect(response).to have_http_status(:success)
      expect(assigns(:short_url)).to eq(short_url)
      expect(assigns(:target_url)).to eq(short_url.target_url)
    end

    it "returns not found for missing slug" do
      get :show, params: { id: "nonexistent" }

      expect(response).to have_http_status(:not_found)
    end
  end
end
