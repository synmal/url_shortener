require "rails_helper"

RSpec.describe "User views dashboard", type: :system do
  let(:user) { create(:user) }

  before { login_as user }

  scenario "shows user's short URLs" do
    target_url = create(:target_url, url: "https://example.com")
    short_url = create(:short_url, user: user, target_url: target_url)

    visit dashboard_path

    expect(page).to have_text(short_url.slug)
    expect(page).to have_link("Metrics", href: short_url_metrics_path(short_url.slug))
  end

  scenario "shows empty state when no URLs" do
    visit dashboard_path

    expect(page).to have_text("You haven't shortened any URLs yet.")
  end

  scenario "hides other users' URLs" do
    other_user = create(:user)
    create(:short_url, user: other_user, target_url: create(:target_url))

    visit dashboard_path

    expect(page).to have_text("You haven't shortened any URLs yet.")
  end

  scenario "navigates to metrics page" do
    short_url = create(:short_url, user: user, target_url: create(:target_url))

    visit dashboard_path
    click_link "Metrics"

    expect(page).to have_current_path(short_url_metrics_path(short_url.slug))
  end
end
