require "rails_helper"

RSpec.describe FetchTitleWorker, type: :job do
  describe "#perform" do
    it "skips when target_url is not found" do
      expect {
        described_class.perform_now(-1)
      }.not_to raise_error
    end

    it "skips when target_url already has a title" do
      target_url = create(:target_url, title: "Existing Title")
      expect(TitleFetcherService).not_to receive(:call)

      described_class.perform_now(target_url.id)
    end

    it "fetches and updates the title" do
      target_url = create(:target_url, url: "https://example.com", title: nil)
      stub_request(:get, "https://example.com")
        .to_return(body: "<html><head><title>Fetched</title></head></html>", status: 200)

      described_class.perform_now(target_url.id)

      expect(target_url.reload.title).to eq("Fetched")
    end

    it "broadcasts a Turbo Stream update when title is fetched" do
      target_url = create(:target_url, url: "https://example.com", title: nil)
      stub_request(:get, "https://example.com")
        .to_return(body: "<html><head><title>Fetched</title></head></html>", status: 200)

      expect(Turbo::StreamsChannel).to receive(:broadcast_update_to).with(
        "target_url_#{target_url.id}",
        target: "page_title",
        partial: "target_urls/title",
        locals: { target_url: target_url }
      )

      described_class.perform_now(target_url.id)
    end

    it "does not broadcast when title fetch returns nil" do
      target_url = create(:target_url, url: "https://example.com", title: nil)
      stub_request(:get, "https://example.com")
        .to_return(body: "<html><head></head></html>", status: 200)

      expect(Turbo::StreamsChannel).not_to receive(:broadcast_update_to)

      described_class.perform_now(target_url.id)
    end

    it "does not raise when broadcast fails" do
      target_url = create(:target_url, url: "https://example.com", title: nil)
      stub_request(:get, "https://example.com")
        .to_return(body: "<html><head><title>Fetched</title></head></html>", status: 200)
      allow(Turbo::StreamsChannel).to receive(:broadcast_update_to).and_raise(StandardError, "broadcast error")

      expect {
        described_class.perform_now(target_url.id)
      }.not_to raise_error

      expect(target_url.reload.title).to eq("Fetched")
    end
  end
end
