require "rails_helper"

RSpec.describe "User signs up and shortens URL", type: :system do
  let(:target_url) { "https://example.com" }

  before do
    stub_request(:get, target_url).to_return(status: 200, body: "<html><title>Example</title></html>")
  end

  scenario "signs up and sees URL form" do
    visit new_user_registration_path

    fill_in "Email", with: "user@example.com"
    fill_in "Password", with: "password123"
    fill_in "Password confirmation", with: "password123"
    click_button "Sign Up"

    expect(page).to have_current_path(root_path)
    expect(page).to have_text("Shorten a URL")
  end

  scenario "shortens a valid URL" do
    user = create(:user)
    login_as user
    visit root_path

    fill_in "URL", with: target_url
    click_button "Shorten"

    expect(page).to have_text("Original URL")
    expect(page).to have_css("#short_url_input")
  end

  scenario "result shows target URL" do
    user = create(:user)
    login_as user
    visit root_path

    fill_in "URL", with: target_url
    click_button "Shorten"

    expect(page).to have_link(target_url, href: target_url)
  end

  scenario "shortens another URL" do
    user = create(:user)
    login_as user
    visit root_path

    fill_in "URL", with: target_url
    click_button "Shorten"

    click_link "Shorten another"

    expect(page).to have_text("Shorten a URL")
    expect(page).to have_button("Shorten")
  end
end
