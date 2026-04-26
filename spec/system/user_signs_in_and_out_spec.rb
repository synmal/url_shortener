require "rails_helper"

RSpec.describe "User signs in and out", type: :system do
  let(:user) { create(:user) }

  scenario "signs in via form" do
    visit new_user_session_path

    fill_in "Email", with: user.email
    fill_in "Password", with: "password123"
    click_button "Sign In"

    expect(page).to have_current_path(root_path)
  end

  scenario "unauthenticated visit to dashboard redirects to sign in" do
    visit dashboard_path

    expect(page).to have_current_path(new_user_session_path)
  end

  scenario "unauthenticated visit to root redirects to sign in" do
    visit root_path

    expect(page).to have_current_path(new_user_session_path)
  end

  scenario "navbar shows user info after sign in" do
    login_as user
    visit root_path

    expect(page).to have_text(user.email)
    expect(page).to have_button("Sign Out")
  end

  scenario "signs out" do
    login_as user
    visit root_path

    click_button "Sign Out"

    expect(page).to have_current_path(new_user_session_path)
  end
end
