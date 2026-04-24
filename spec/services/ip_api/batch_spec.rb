require "rails_helper"

RSpec.describe IpApi::Batch do
  describe ".call" do
    let(:success_body) do
      [
        { status: "success", query: "1.2.3.4", lat: 37.7749, lon: -122.4194, country: "United States" },
        { status: "success", query: "5.6.7.8", lat: 51.5074, lon: -0.1278, country: "United Kingdom" }
      ].to_json
    end

    let(:mixed_body) do
      [
        { status: "success", query: "1.2.3.4", lat: 37.7749, lon: -122.4194, country: "United States" },
        { status: "fail", query: "invalid" }
      ].to_json
    end

    it "returns geo data for successful results" do
      stub_request(:post, "http://ip-api.com/batch")
        .to_return(body: success_body, status: 200, headers: { "X-Rl" => "140", "X-Ttl" => "60" })

      result = described_class.call(["1.2.3.4", "5.6.7.8"])

      expect(result.success?).to be true
      expect(result.data.size).to eq(2)
      expect(result.data.first[:country]).to eq("United States")
      expect(result.data.last[:country]).to eq("United Kingdom")
      expect(result.rate_limit_remaining).to eq(140)
      expect(result.rate_limit_ttl).to eq(60)
    end

    it "filters out failed results" do
      stub_request(:post, "http://ip-api.com/batch")
        .to_return(body: mixed_body, status: 200, headers: { "X-Rl" => "140", "X-Ttl" => "60" })

      result = described_class.call(["1.2.3.4", "invalid"])

      expect(result.success?).to be true
      expect(result.data.size).to eq(1)
      expect(result.data.first[:query]).to eq("1.2.3.4")
    end

    it "returns failure result when request fails" do
      stub_request(:post, "http://ip-api.com/batch").to_timeout

      expect(Rails.logger).to receive(:error).with(/\[IpApi::Batch\] Request failed/)
      result = described_class.call(["1.2.3.4"])

      expect(result.success?).to be false
      expect(result.data).to be_empty
      expect(result.rate_limit_remaining).to eq(0)
      expect(result.rate_limit_ttl).to eq(60)
    end

    it "returns failure result when response is not JSON" do
      stub_request(:post, "http://ip-api.com/batch")
        .to_return(body: "<html>Server Error</html>", status: 500, headers: { "Content-Type" => "text/html" })

      expect(Rails.logger).to receive(:error).with(/\[IpApi::Batch\] Request failed/)
      result = described_class.call(["1.2.3.4"])

      expect(result.success?).to be false
      expect(result.data).to be_empty
    end

    it "returns success for empty input" do
      result = described_class.call([])

      expect(result.success?).to be true
      expect(result.data).to be_empty
      expect(result.rate_limit_remaining).to eq(0)
    end

    it "raises on non-array input" do
      expect { described_class.call("1.2.3.4") }.to raise_error(ArgumentError, /must be an Array/)
    end

    it "raises when input exceeds batch size" do
      expect { described_class.call(Array.new(101) { "1.2.3.4" }) }.to raise_error(ArgumentError, /cannot exceed/)
    end
  end
end
