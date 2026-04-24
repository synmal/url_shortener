require "rails_helper"

RSpec.describe TargetUrl, type: :model do
  describe "associations" do
    it { should have_many(:short_urls).dependent(:destroy) }
    it { should have_many(:visits).through(:short_urls) }
  end

  describe "validations" do
    it { should validate_presence_of(:url) }

    it "accepts valid http url" do
      expect(build(:target_url, url: "http://example.com")).to be_valid
    end

    it "accepts valid https url" do
      expect(build(:target_url, url: "https://example.com")).to be_valid
    end

    it "rejects url without host" do
      expect(build(:target_url, url: "http://")).not_to be_valid
    end

    it "rejects url with query only" do
      expect(build(:target_url, url: "http://?")).not_to be_valid
    end

    it "rejects invalid scheme" do
      target_url = build(:target_url, url: "ftp://example.com")
      expect(target_url).not_to be_valid
      expect(target_url.errors[:url]).to include("must be a valid HTTP or HTTPS URL with a host")
    end

    it "rejects javascript urls" do
      expect(build(:target_url, url: "javascript:alert(1)")).not_to be_valid
    end

    it "rejects non-url strings" do
      expect(build(:target_url, url: "not-a-url")).not_to be_valid
    end

    it "cascades destroy to short urls" do
      target_url = create(:target_url)
      short_url = create(:short_url, target_url: target_url)

      expect { target_url.destroy }.to change(ShortUrl, :count).by(-1)
    end
  end
end
