class Base58Service
  def self.generate(length: SecureRandom.random_number(4..15))
    SecureRandom.base58(length.clamp(4, 15))
  end
end
