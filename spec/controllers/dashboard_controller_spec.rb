require "rails_helper"

RSpec.describe DashboardController, type: :controller do
  render_views

  let(:user) { create(:user) }

  describe "GET #index" do
    before { sign_in user }

    it "returns http success" do
      get :index

      expect(response).to have_http_status(:success)
    end

    it "assigns paginated short URLs for the current user" do
      short_url = create(:short_url, user:)

      get :index

      expect(assigns(:short_urls)).to include(short_url)
      expect(assigns(:pagy)).to be_present
    end

    it "does not include other users' short URLs" do
      other_user = create(:user)
      create(:short_url, user: other_user)
      my_short_url = create(:short_url, user:)

      get :index

      expect(assigns(:short_urls)).to include(my_short_url)
      expect(assigns(:short_urls)).not_to include(other_user.short_urls.first)
    end

    it "orders by most recent first" do
      older = create(:short_url, user:, created_at: 2.days.ago)
      newer = create(:short_url, user:, created_at: 1.day.ago)

      get :index

      expect(assigns(:short_urls).index(newer)).to be < assigns(:short_urls).index(older)
    end
  end

  describe "authentication" do
    it "redirects to sign in" do
      get :index

      expect(response).to redirect_to(new_user_session_path)
    end
  end
end
