class TargetUrlForm
  include ActiveModel::Model

  attr_accessor :url

  validates :url, presence: true, format: { with: /\Ahttps?:\/\//, message: "must start with http:// or https://" }
end
