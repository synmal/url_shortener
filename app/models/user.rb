class User < ApplicationRecord
  devise :database_authenticatable, :registerable, :rememberable, :validatable

  has_many :short_urls, dependent: :destroy
  has_many :target_urls, through: :short_urls
end
