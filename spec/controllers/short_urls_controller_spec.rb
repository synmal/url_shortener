require "rails_helper"

RSpec.describe ShortUrlsController, type: :controller do
  describe "GET #show" do
    it "redirects to the target URL" do
      short_url = create(:short_url, target_url: create(:target_url, url: "https://example.com"))

      get :show, params: { slug: short_url.slug }

      expect(response).to redirect_to("https://example.com")
      expect(response).to have_http_status(:found)
    end

    it "creates a visit record" do
      short_url = create(:short_url)

      expect {
        get :show, params: { slug: short_url.slug }
      }.to change(Visit, :count).by(1)

      visit = Visit.last
      expect(visit.short_url).to eq(short_url)
      expect(visit.ip_address).to eq("0.0.0.0")
    end

    it "increments visits_count on the short URL" do
      short_url = create(:short_url, visits_count: 0)

      get :show, params: { slug: short_url.slug }

      expect(short_url.reload.visits_count).to eq(1)
    end

    it "handles visit creation failure gracefully" do
      short_url = create(:short_url)
      allow(Visit).to receive(:new).and_raise(ActiveRecord::RecordInvalid.new(Visit.new))

      expect {
        get :show, params: { slug: short_url.slug }
      }.not_to change(Visit, :count)

      expect(response).to redirect_to(short_url.reload.target_url.url)
    end

    it "returns not found for missing slug" do
      get :show, params: { slug: "nonexistent" }

      expect(response).to have_http_status(:not_found)
    end
  end
end
