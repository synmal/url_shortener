require "rails_helper"

RSpec.describe BatchProcessVisitsWorker do
  before do
    # Stub Redis for rate limit checks — tests that need specific stubs override this
    allow(AppRedis).to receive(:with) { |&block| block.call(double(get: nil, set: true)) }
  end

  describe "#perform" do
    it "enriches unprocessed visits with geo data" do
      short_url = create(:short_url)
      visit = create(:visit, short_url:, ip_address: "1.2.3.4")

      stub_batch_result([ { query: "1.2.3.4", lat: 37.7749, lon: -122.4194, country: "United States" } ])

      described_class.perform_now

      visit.reload
      expect(visit.latitude).to eq(37.7749)
      expect(visit.longitude).to eq(-122.4194)
      expect(visit.country).to eq("United States")
      expect(visit.processed_at).to be_present
    end

    it "returns early when no unprocessed visits exist" do
      expect(IpApi::Batch).not_to receive(:call)
      described_class.perform_now
    end

    it "skips rate-limited execution" do
      short_url = create(:short_url)
      create(:visit, short_url:, ip_address: "1.2.3.4")

      redis_double = double(get: "0", set: true)
      allow(AppRedis).to receive(:with) { |&block| block.call(redis_double) }

      expect(IpApi::Batch).not_to receive(:call)
      described_class.perform_now
    end

    it "persists rate limit after successful batch" do
      short_url = create(:short_url)
      create(:visit, short_url:, ip_address: "1.2.3.4")

      stub_batch_result([ { query: "1.2.3.4", lat: 37.7749, lon: -122.4194, country: "US" } ], remaining: 140, ttl: 60)

      redis_double = double(get: nil, set: true)
      expect(redis_double).to receive(:set).with("ip_api:rate_limit_remaining", 140, ex: 60)
      allow(AppRedis).to receive(:with) { |&block| block.call(redis_double) }

      described_class.perform_now
    end

    it "re-enqueues when more unprocessed visits remain" do
      short_url = create(:short_url)
      create(:visit, short_url:, ip_address: "1.2.3.4")
      create(:visit, short_url:, ip_address: "5.6.7.8")

      stub_batch_result([ { query: "1.2.3.4", lat: 37.7, lon: -122.4, country: "US" } ])

      # Simulate new visits arriving between batch processing and re-enqueue check
      scope = Visit.unprocessed
      allow(Visit).to receive(:unprocessed).and_return(scope)
      allow(scope).to receive(:exists?).and_return(true)

      expect(BatchProcessVisitsWorker).to receive(:set).with(wait: 30.seconds).and_return(double(perform_later: true))

      described_class.perform_now
    end

    it "raises on API failure for Sidekiq retry" do
      short_url = create(:short_url)
      create(:visit, short_url:, ip_address: "1.2.3.4")

      allow(IpApi::Batch).to receive(:call).and_return(
        IpApi::Batch::Result.new(data: [], rate_limit_remaining: 0, rate_limit_ttl: 60, success?: false)
      )

      expect { described_class.perform_now }.to raise_error(RuntimeError, /request failed/)
    end

    it "marks visits as processed even when no geo data returned" do
      short_url = create(:short_url)
      visit = create(:visit, short_url:, ip_address: "1.2.3.4")

      stub_batch_result([])

      described_class.perform_now

      expect(visit.reload.processed_at).to be_present
      expect(visit.latitude).to be_nil
    end

    it "marks visits as processed via update_column when geo data fails validation" do
      short_url = create(:short_url)
      visit = create(:visit, short_url:, ip_address: "1.2.3.4")

      stub_batch_result([ { query: "1.2.3.4", lat: 999, lon: -122.4, country: "US" } ])

      described_class.perform_now

      visit.reload
      expect(visit.processed_at).to be_present
      expect(visit.latitude).to be_nil
    end
  end

  private

  def stub_batch_result(data, remaining: 140, ttl: 60)
    allow(IpApi::Batch).to receive(:call).and_return(
      IpApi::Batch::Result.new(data:, rate_limit_remaining: remaining, rate_limit_ttl: ttl, success?: true)
    )
  end
end
