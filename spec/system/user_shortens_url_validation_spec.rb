require "rails_helper"

RSpec.describe "URL shortening validation", type: :system do
  let(:user) { create(:user) }

  before { login_as user }

  scenario "shows error for blank URL" do
    visit root_path

    click_button "Shorten"

    expect(page).to have_css(".is-invalid")
    expect(page).to have_text("can't be blank")
  end

  scenario "shows error for invalid scheme" do
    visit root_path

    fill_in "URL", with: "ftp://example.com"
    click_button "Shorten"

    expect(page).to have_css(".is-invalid")
    expect(page).to have_text("must start with http:// or https://")
  end

  scenario "shows error for self-referencing URL" do
    ENV["APP_HOST"] = "www.example.com"
    visit root_path

    fill_in "URL", with: "http://www.example.com"
    click_button "Shorten"

    expect(page).to have_css(".is-invalid")
    expect(page).to have_text("cannot point to this application")
  ensure
    ENV.delete("APP_HOST")
  end
end
