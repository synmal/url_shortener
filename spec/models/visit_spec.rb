require "rails_helper"

RSpec.describe Visit, type: :model do
  describe "associations" do
    it { should belong_to(:short_url) }
  end

  describe "validations" do
    it { should validate_presence_of(:ip_address) }
    it { should validate_presence_of(:visited_at) }

    it "accepts valid IPv4 address" do
      expect(build(:visit, ip_address: "192.168.1.1")).to be_valid
    end

    it "accepts valid IPv6 address" do
      expect(build(:visit, ip_address: "::1")).to be_valid
      expect(build(:visit, ip_address: "2001:db8::1")).to be_valid
    end

    it "accepts IPv4-mapped IPv6 address" do
      expect(build(:visit, ip_address: "::ffff:192.168.1.1")).to be_valid
    end

    it "rejects invalid IP address" do
      expect(build(:visit, ip_address: "hello")).not_to be_valid
    end

    it "rejects malformed IP address" do
      expect(build(:visit, ip_address: "1.2.3.4.5")).not_to be_valid
    end

    it "is valid with only required fields" do
      visit = Visit.new(short_url: create(:short_url), ip_address: "10.0.0.1", visited_at: Time.current)
      expect(visit).to be_valid
    end

    it "rejects latitude out of range" do
      expect(build(:visit, latitude: 91)).not_to be_valid
      expect(build(:visit, latitude: -91)).not_to be_valid
    end

    it "accepts valid latitude range" do
      expect(build(:visit, latitude: 90)).to be_valid
      expect(build(:visit, latitude: -90)).to be_valid
    end

    it "rejects longitude out of range" do
      expect(build(:visit, longitude: 181)).not_to be_valid
      expect(build(:visit, longitude: -181)).not_to be_valid
    end

    it "accepts valid longitude range" do
      expect(build(:visit, longitude: 180)).to be_valid
      expect(build(:visit, longitude: -180)).to be_valid
    end
  end

  describe "scopes" do
    describe ".unprocessed" do
      it "returns visits without processed_at" do
        unprocessed = create(:visit, processed_at: nil)
        processed = create(:visit, processed_at: 1.hour.ago)

        expect(described_class.unprocessed).to include(unprocessed)
        expect(described_class.unprocessed).not_to include(processed)
      end
    end
  end
end
