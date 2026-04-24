require "rails_helper"

RSpec.describe TitleFetcherService do
  describe ".call" do
    context "when the page has a title" do
      it "returns the title text" do
        stub_request(:get, "http://example.com")
          .to_return(body: "<html><head><title>Example Site</title></head><body></body></html>", status: 200)

        expect(TitleFetcherService.call("http://example.com")).to eq("Example Site")
      end
    end

    context "when the page has no title tag" do
      it "returns nil" do
        stub_request(:get, "http://example.com")
          .to_return(body: "<html><head></head><body></body></html>", status: 200)

        expect(TitleFetcherService.call("http://example.com")).to be_nil
      end
    end

    context "when the title is blank" do
      it "returns nil" do
        stub_request(:get, "http://example.com")
          .to_return(body: "<html><head><title>  </title></head><body></body></html>", status: 200)

        expect(TitleFetcherService.call("http://example.com")).to be_nil
      end
    end

    context "when the request times out" do
      it "returns nil and logs a warning" do
        stub_request(:get, "http://example.com").to_timeout

        expect(Rails.logger).to receive(:warn).with(/\[TitleFetcherService\] Failed to fetch title/)
        expect(TitleFetcherService.call("http://example.com")).to be_nil
      end
    end

    context "when the server returns 404" do
      it "returns nil without logging" do
        stub_request(:get, "http://example.com")
          .to_return(body: "Not Found", status: 404)

        expect(TitleFetcherService.call("http://example.com")).to be_nil
      end
    end

    context "when DNS resolution fails" do
      it "returns nil and logs a warning" do
        stub_request(:get, "http://nonexistent.invalid").to_raise(SocketError)

        expect(Rails.logger).to receive(:warn).with(/\[TitleFetcherService\] Failed to fetch title/)
        expect(TitleFetcherService.call("http://nonexistent.invalid")).to be_nil
      end
    end

    context "when the URL is blank" do
      it "raises ArgumentError" do
        expect { TitleFetcherService.call("") }.to raise_error(ArgumentError, /cannot be blank/)
      end
    end
  end
end
