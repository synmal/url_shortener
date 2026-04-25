require "rails_helper"

RSpec.describe LinkShortenerService do
  describe ".call" do
    let(:user) { create(:user) }

    context "with a valid URL" do
      it "creates a target URL and short URL" do
        result = described_class.call("https://example.com/page", user:)

        expect(result.target_url).to be_persisted
        expect(result.target_url.url).to eq("https://example.com/page")
        expect(result.short_url).to be_persisted
        expect(result.short_url.slug).to match(ShortUrl::BASE58_SLUG)
        expect(result.short_url.user).to eq(user)
      end

      it "removes URL fragments" do
        result = described_class.call("https://example.com/page#section", user:)

        expect(result.target_url.url).to eq("https://example.com/page")
      end

      it "normalizes scheme and host to lowercase" do
        result = described_class.call("HTTPS://EXAMPLE.COM/page", user:)

        expect(result.target_url.url).to eq("https://example.com/page")
      end

      it "reuses an existing target URL" do
        existing = create(:target_url, url: "https://example.com")

        result = described_class.call("https://example.com", user:)

        expect(result.target_url).to eq(existing)
        expect(TargetUrl.count).to eq(1)
      end

      it "creates a new short URL even for existing target URL" do
        create(:target_url, url: "https://example.com")
        create(:short_url, target_url: TargetUrl.first)

        result = described_class.call("https://example.com", user:)

        expect(result.short_url).to be_persisted
        expect(ShortUrl.count).to eq(2)
      end
    end

    context "with invalid input" do
      it "raises on blank URL" do
        expect { described_class.call("", user:) }.to raise_error(ArgumentError, /cannot be blank/)
        expect { described_class.call("  ", user:) }.to raise_error(ArgumentError, /cannot be blank/)
      end

      it "raises on missing scheme" do
        expect { described_class.call("example.com", user:) }.to raise_error(ArgumentError, /Invalid URL/)
      end

      it "raises on invalid scheme" do
        expect { described_class.call("ftp://example.com", user:) }.to raise_error(ArgumentError, /Invalid URL/)
      end

      it "raises on malformed URL" do
        expect { described_class.call("not a url", user:) }.to raise_error(ArgumentError)
      end

      it "raises when user is nil" do
        expect { described_class.call("https://example.com", user: nil) }.to raise_error(ArgumentError, /User is required/)
      end
    end

    context "slug collision handling" do
      it "retries on RecordNotUnique collision" do
        allow(Base58Service).to receive(:generate).and_return("taken", "unique")
        create(:short_url, slug: "taken")

        result = described_class.call("https://example.com", user:)

        expect(result.short_url.slug).to eq("unique")
      end

      it "retries on RecordInvalid with slug uniqueness error" do
        allow(Base58Service).to receive(:generate).and_return("taken", "unique")
        create(:short_url, slug: "taken")

        call_count = 0
        ShortUrl.set_callback(:validate, :before) do
          if (call_count += 1) == 1
            errors.add(:slug, "has already been taken")
          end
        end

        result = described_class.call("https://example.com", user:)

        expect(result.short_url.slug).to eq("unique")
      ensure
        ShortUrl.skip_callback(:validate, :before)
      end

      it "raises after max retries exhausted" do
        allow(Base58Service).to receive(:generate).and_return("taken")
        create(:short_url, slug: "taken")

        expect { described_class.call("https://example.com", user:) }.to raise_error(ArgumentError, /Failed to generate unique slug/)
      end
    end

    context "transaction rollback" do
      it "rolls back both records on failure" do
        allow(Base58Service).to receive(:generate).and_return("taken")
        create(:short_url, slug: "taken")
        initial_target_count = TargetUrl.count
        initial_short_count = ShortUrl.count

        expect {
          described_class.call("https://example.com", user:)
        }.to raise_error(ArgumentError)

        expect(TargetUrl.count).to eq(initial_target_count)
        expect(ShortUrl.count).to eq(initial_short_count)
      end
    end
  end
end
