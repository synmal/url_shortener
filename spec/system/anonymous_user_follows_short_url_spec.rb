require "rails_helper"

RSpec.describe "Anonymous user follows short URL", type: :system do
  let(:target_url) { "https://example.com/page" }

  before do
    stub_request(:get, target_url).to_return(status: 200, body: "OK")
  end

  scenario "redirects to the target URL" do
    short_url = create(:short_url, target_url: create(:target_url, url: target_url))

    visit "/#{short_url.slug}"

    expect(page).to have_current_path(URI.parse(target_url).request_uri)
  end

  scenario "creates a visit record" do
    short_url = create(:short_url, target_url: create(:target_url, url: target_url))

    visit "/#{short_url.slug}"

    visit_record = short_url.visits.last
    expect(visit_record).to be_present
    expect(visit_record.ip_address).to eq("127.0.0.1")
  end

  scenario "increments the visits counter" do
    short_url = create(:short_url, target_url: create(:target_url, url: target_url))

    visit "/#{short_url.slug}"

    expect(short_url.reload.visits_count).to eq(1)
  end

  scenario "returns 404 for nonexistent slug" do
    visit "/nonexistent"

    expect(page.status_code).to eq(404)
  end
end
