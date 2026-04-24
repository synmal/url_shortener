require "rails_helper"

RSpec.describe Base58Service do
  describe ".generate" do
    it "uses a random length between 4 and 15 by default" do
      lengths = 100.times.map { Base58Service.generate.length }
      expect(lengths.min).to be >= 4
      expect(lengths.max).to be <= 15
      expect(lengths.uniq.size).to be > 1
    end

    it "respects a given length" do
      slug = Base58Service.generate(length: 8)
      expect(slug.length).to eq(8)
    end

    it "clamps lengths below 4" do
      expect(Base58Service.generate(length: 1).length).to eq(4)
      expect(Base58Service.generate(length: 0).length).to eq(4)
      expect(Base58Service.generate(length: -5).length).to eq(4)
    end

    it "clamps lengths above 15" do
      expect(Base58Service.generate(length: 20).length).to eq(15)
      expect(Base58Service.generate(length: 100).length).to eq(15)
    end
  end
end
