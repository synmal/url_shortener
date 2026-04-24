require "rails_helper"

RSpec.describe ShortUrl, type: :model do
  describe "associations" do
    it { should belong_to(:target_url) }
    it { should have_many(:visits).dependent(:destroy) }
  end

  describe "validations" do
    it { should validate_presence_of(:slug) }

    it "validates slug format" do
      expect(build(:short_url, slug: "abc!")).not_to be_valid
      expect(build(:short_url, slug: "ab")).not_to be_valid
      expect(build(:short_url, slug: "a" * 16)).not_to be_valid
    end

    it "validates slug uniqueness" do
      existing = create(:short_url)
      duplicate = build(:short_url, slug: existing.slug)
      expect(duplicate).not_to be_valid
    end

    it "treats slugs as case-sensitive" do
      create(:short_url, slug: "abc123")
      expect(build(:short_url, slug: "ABC123")).to be_valid
    end
  end

  describe "#increment_visits!" do
    it "atomically increments visits_count" do
      short_url = create(:short_url, visits_count: 0)

      short_url.increment_visits!

      expect(short_url.reload.visits_count).to eq(1)
    end

    it "increments from a non-zero base" do
      short_url = create(:short_url, visits_count: 5)

      short_url.increment_visits!

      expect(short_url.reload.visits_count).to eq(6)
    end

    it "raises on unsaved record" do
      short_url = build(:short_url)

      expect { short_url.increment_visits! }.to raise_error(ArgumentError, /unsaved record/)
    end

    it "raises on deleted record" do
      short_url = create(:short_url, visits_count: 0)
      short_url.destroy

      expect { short_url.increment_visits! }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "destroy" do
    it "cascades destroy to visits" do
      short_url = create(:short_url)
      create(:visit, short_url: short_url)

      expect { short_url.destroy }.to change(Visit, :count).by(-1)
    end
  end

  describe "attr_readonly" do
    it "prevents direct assignment of visits_count" do
      short_url = create(:short_url, visits_count: 0)

      expect { short_url.update(visits_count: 99) }.to raise_error(ActiveRecord::ReadonlyAttributeError)
      expect(short_url.reload.visits_count).to eq(0)
    end
  end
end
