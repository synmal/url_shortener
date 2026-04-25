require "rails_helper"

RSpec.describe MetricsController, type: :controller do
  render_views

  describe "GET #show" do
    it "returns http success" do
      short_url = create(:short_url)

      get :show, params: { slug: short_url.slug }

      expect(response).to have_http_status(:success)
      expect(assigns(:short_url)).to eq(short_url)
    end

    it "assigns visits grouped by country" do
      short_url = create(:short_url)
      create(:visit, short_url: short_url, country: "US")
      create(:visit, short_url: short_url, country: "US")
      create(:visit, short_url: short_url, country: "GB")

      get :show, params: { slug: short_url.slug }

      expect(assigns(:visits_by_country)).to eq({ "US" => 2, "GB" => 1 })
    end

    it "orders visits by country count descending" do
      short_url = create(:short_url)
      create(:visit, short_url: short_url, country: "GB")
      create(:visit, short_url: short_url, country: "US")
      create(:visit, short_url: short_url, country: "US")
      create(:visit, short_url: short_url, country: "US")

      get :show, params: { slug: short_url.slug }

      expect(assigns(:visits_by_country).keys).to eq(%w[US GB])
    end

    it "assigns paginated recent visits" do
      short_url = create(:short_url)
      visits = create_list(:visit, 5, short_url: short_url)

      get :show, params: { slug: short_url.slug }

      expect(assigns(:recent_visits).size).to eq(5)
      expect(assigns(:pagy)).to be_present
    end

    it "paginates recent visits" do
      short_url = create(:short_url)
      create_list(:visit, 30, short_url: short_url)

      get :show, params: { slug: short_url.slug }

      expect(assigns(:recent_visits).size).to be <= 30
      expect(assigns(:pagy).count).to eq(30)
    end

    it "returns not found for missing slug" do
      get :show, params: { slug: "nonexistent" }

      expect(response).to have_http_status(:not_found)
    end

    it "returns empty country breakdown with no visits" do
      short_url = create(:short_url)

      get :show, params: { slug: short_url.slug }

      expect(assigns(:visits_by_country)).to be_empty
      expect(assigns(:recent_visits)).to be_empty
    end
  end
end
