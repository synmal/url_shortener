require "rails_helper"

RSpec.describe "User views metrics", type: :system do
  let(:user) { create(:user) }
  let(:short_url) { create(:short_url, user: user, target_url: create(:target_url)) }

  before { login_as user }

  scenario "shows visit stats" do
    create(:visit, short_url: short_url, country: "US")
    create(:visit, short_url: short_url, country: "US")
    create(:visit, short_url: short_url, country: "GB")
    ShortUrl.update_counters(short_url.id, visits_count: 3)

    visit short_url_metrics_path(short_url.slug)

    expect(page).to have_text("Total Visits")
    expect(page).to have_css(".fs-3", text: "3")
    expect(page).to have_text("US")
    expect(page).to have_text("GB")
  end

  scenario "shows recent visits table" do
    create(:visit, short_url: short_url, ip_address: "1.2.3.4", country: "US", visited_at: Time.current)

    visit short_url_metrics_path(short_url.slug)

    expect(page).to have_text("1.2.3.4")
    expect(page).to have_text("US")
  end

  scenario "shows empty state when no visits" do
    visit short_url_metrics_path(short_url.slug)

    expect(page).to have_text("No visits yet")
  end

  scenario "returns 404 for other user's metrics" do
    other_user = create(:user)
    other_short_url = create(:short_url, user: other_user, target_url: create(:target_url))

    visit short_url_metrics_path(other_short_url.slug)

    expect(page.status_code).to eq(404)
  end
end
