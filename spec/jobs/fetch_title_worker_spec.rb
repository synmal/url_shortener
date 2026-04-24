require "rails_helper"

RSpec.describe FetchTitleWorker do
  describe "#perform" do
    it "fetches and sets title on target URL" do
      target_url = create(:target_url, url: "http://example.com")
      allow(TitleFetcherService).to receive(:call).with("http://example.com").and_return("Example Site")

      described_class.perform_now(target_url.id)

      expect(target_url.reload.title).to eq("Example Site")
    end

    it "skips when title already present" do
      target_url = create(:target_url, url: "http://example.com", title: "Existing")

      expect(TitleFetcherService).not_to receive(:call)
      described_class.perform_now(target_url.id)
    end

    it "does not set title when fetcher returns nil" do
      target_url = create(:target_url, url: "http://example.com")
      allow(TitleFetcherService).to receive(:call).with("http://example.com").and_return(nil)

      described_class.perform_now(target_url.id)

      expect(target_url.reload.title).to be_nil
    end

    it "handles missing target URL gracefully" do
      expect(TitleFetcherService).not_to receive(:call)
      expect { described_class.perform_now(999999) }.not_to raise_error
    end

    it "propagates unexpected errors for Sidekiq retry" do
      target_url = create(:target_url, url: "http://example.com")
      allow(TitleFetcherService).to receive(:call).and_raise(StandardError, "boom")

      expect { described_class.perform_now(target_url.id) }.to raise_error(StandardError, "boom")
    end
  end
end
