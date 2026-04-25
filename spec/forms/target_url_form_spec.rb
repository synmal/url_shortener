require "rails_helper"

RSpec.describe TargetUrlForm do
  describe "validations" do
    it "is valid with a proper URL" do
      form = TargetUrlForm.new(url: "https://example.com")
      expect(form).to be_valid
    end

    it "requires url presence" do
      form = TargetUrlForm.new(url: nil)
      expect(form).not_to be_valid
      expect(form.errors[:url]).to include("can't be blank")
    end

    it "rejects URL without http/https scheme" do
      form = TargetUrlForm.new(url: "ftp://example.com")
      expect(form).not_to be_valid
      expect(form.errors[:url]).to include("must start with http:// or https://")
    end

    it "rejects URL with no scheme" do
      form = TargetUrlForm.new(url: "example.com")
      expect(form).not_to be_valid
    end
  end
end
