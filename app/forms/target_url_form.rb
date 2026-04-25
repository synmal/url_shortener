# Separates input validation from model/persistence concerns.
# The controller validates user input here, then passes a format-validated URL
# to LinkShortenerService which handles the transactional write.
class TargetUrlForm
  include ActiveModel::Model

  attr_accessor :url

  validates :url, presence: true, format: { with: /\Ahttps?:\/\//, message: "must start with http:// or https://" }
end
