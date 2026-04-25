require "rails_helper"

RSpec.describe User, type: :model do
  subject { build(:user) }

  it { should validate_presence_of(:email) }
  it { should validate_uniqueness_of(:email).case_insensitive }
  it { should validate_presence_of(:password) }

  it { should have_many(:short_urls).dependent(:destroy) }
  it { should have_many(:target_urls).through(:short_urls) }

  it "authenticates with valid credentials" do
    user = create(:user, password: "secret123")
    expect(user.valid_password?("secret123")).to be true
  end

  it "rejects invalid password" do
    user = create(:user, password: "secret123")
    expect(user.valid_password?("wrong")).to be false
  end
end
