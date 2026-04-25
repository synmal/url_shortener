require "rails_helper"

RSpec.describe IpAddressValidator do
  let(:record) { Visit.new }
  let(:validator) { described_class.new(attributes: [:ip_address]) }

  before { validator.validate_each(record, :ip_address, value) }

  context "when value is blank" do
    let(:value) { nil }

    it "passes validation" do
      expect(record.errors[:ip_address]).to be_empty
    end
  end

  context "when value is a valid IPv4 address" do
    let(:value) { "192.168.1.1" }

    it "passes validation" do
      expect(record.errors[:ip_address]).to be_empty
    end
  end

  context "when value is a valid IPv6 address" do
    let(:value) { "2001:db8::1" }

    it "passes validation" do
      expect(record.errors[:ip_address]).to be_empty
    end
  end

  context "when value contains CIDR notation" do
    let(:value) { "192.168.1.0/24" }

    it "adds an error" do
      expect(record.errors[:ip_address]).to include("must be a valid IP address")
    end
  end

  context "when value contains a zone ID" do
    let(:value) { "fe80::1%eth0" }

    it "adds an error" do
      expect(record.errors[:ip_address]).to include("must be a valid IP address")
    end
  end

  context "when value is not an IP address" do
    let(:value) { "hello" }

    it "adds an error" do
      expect(record.errors[:ip_address]).to include("must be a valid IP address")
    end
  end
end
