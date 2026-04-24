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

    it "rejects loopback IP addresses" do
      expect(build(:target_url, url: "http://127.0.0.1")).not_to be_valid
      expect(build(:target_url, url: "http://localhost")).not_to be_valid
    end

    it "rejects private IP addresses" do
      expect(build(:target_url, url: "http://10.0.0.1")).not_to be_valid
      expect(build(:target_url, url: "http://192.168.1.1")).not_to be_valid
    end

    it "rejects cloud metadata IP" do
      expect(build(:target_url, url: "http://169.254.169.254")).not_to be_valid
    end

    it "allows public IP addresses" do
      expect(build(:target_url, url: "http://1.1.1.1")).to be_valid
    end

    it "rejects localhost.localdomain" do
      expect(build(:target_url, url: "http://localhost.localdomain")).not_to be_valid
    end

    it "rejects IPv6 loopback" do
      expect(build(:target_url, url: "http://[::1]")).not_to be_valid
    end

    it "rejects IPv6 unique local addresses" do
      expect(build(:target_url, url: "http://[fc00::1]")).not_to be_valid
      expect(build(:target_url, url: "http://[fd00::1]")).not_to be_valid
    end

    it "rejects IPv6 link-local addresses" do
      expect(build(:target_url, url: "http://[fe80::1]")).not_to be_valid
    end

    it "rejects IPv4-mapped IPv6 addresses" do
      expect(build(:target_url, url: "http://[::ffff:192.168.1.1]")).not_to be_valid
    end

    it "rejects carrier-grade NAT range" do
      expect(build(:target_url, url: "http://100.64.0.1")).not_to be_valid
    end

    it "rejects URLs that DNS-resolve to private IPs" do
      allow(Resolv).to receive(:getaddresses).with("evil.com").and_return(["10.0.0.1"])

      expect(build(:target_url, url: "http://evil.com")).not_to be_valid
    end

    it "logs warning when DNS resolution fails" do
      allow(Resolv).to receive(:getaddresses).with("unresolvable.example").and_raise(Resolv::ResolvError)

      expect(Rails.logger).to receive(:warn).with(/\[TargetUrl\] DNS resolution failed/)
      build(:target_url, url: "http://unresolvable.example").valid?
    end
  end

  describe "callbacks" do
    it "cascades destroy to short urls" do
      target_url = create(:target_url)
      create(:short_url, target_url: target_url)

      expect { target_url.destroy }.to change(ShortUrl, :count).by(-1)
    end
  end
end
