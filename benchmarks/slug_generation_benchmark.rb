# frozen_string_literal: true

# Slug Generation Performance Benchmark
#
# Benchmarks all 5 slug generation approaches from the wiki.
# Measures generation throughput and collision rates.
#
# Usage:
#   ruby benchmarks/slug_generation_benchmark.rb
#
# Optional env vars:
#   SAMPLE_SIZE      - number of slugs to generate per approach (default: 100_000)
#   WARMUP_SECONDS   - benchmark warmup time (default: 2)
#   BENCHMARK_SECONDS - benchmark measurement time (default: 5)

# Run via: docker compose run --rm web bin/rails runner benchmarks/slug_generation_benchmark.rb
require "benchmark"
require "digest"
require "set"

BASE58_ALPHABET = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
BASE58_CHARS = BASE58_ALPHABET.chars.freeze

# ---------------------------------------------------------------------------
# Approach implementations
# ---------------------------------------------------------------------------

module Approach1RandomBase58
  def self.generate
    length = SecureRandom.random_number(4..15)
    SecureRandom.base58(length)
  end
end

module Approach2IdToBase58
  def self.encode(id)
    return BASE58_CHARS[0] if id.zero?
    chars = []
    n = id
    while n > 0
      chars << BASE58_CHARS[n % 58]
      n /= 58
    end
    chars.reverse.join
  end

  def self.generate(id)
    encode(id)
  end
end

module Approach3HashTruncation
  def self.generate(url, length: 6)
    Digest::SHA256.hexdigest(url)[0, length]
  end

  # Salted variant for collision retry
  def self.generate_salted(url, salt, length: 6)
    Digest::SHA256.hexdigest("#{url}#{salt}")[0, length]
  end
end

module Approach4Hashids
  # Minimal Hashids implementation (salted permutation encoding)
  # Mirrors the hashids algorithm without the gem dependency.

  def self.setup(salt: "benchmark_salt_2026", min_length: 4)
    @salt = salt
    @min_length = min_length
    @alphabet = BASE58_CHARS.dup
  end

  def self.encode(id)
    setup unless @alphabet

    alphabet = @alphabet.dup
    salt_chars = @salt.chars

    # Salted shuffle
    v = 0
    (0...alphabet.length).each do |i|
      v += (i + alphabet[i].ord + (salt_chars[i % salt_chars.length].ord rescue 0))
      v %= alphabet.length
      alphabet[i], alphabet[v] = alphabet[v], alphabet[i]
    end

    # Encode
    result = []
    n = id
    while n > 0
      result << alphabet[n % alphabet.length]
      n /= alphabet.length
    end
    result.reverse!

    # Pad to min_length
    while result.length < @min_length
      result.insert(0, alphabet[(result.length + id) % alphabet.length])
    end

    result.join
  end

  def self.generate(id)
    encode(id)
  end
end

module Approach5Snowflake
  # Simplified Snowflake: 41-bit timestamp | 10-bit machine | 12-bit sequence

  EPOCH = Time.utc(2026, 1, 1).to_i * 1000

  def self.setup(machine_id: 1)
    @machine_id = machine_id & 0x3FF
    @sequence = 0
    @last_ms = 0
    @mutex = Mutex.new
  end

  def self.generate
    setup unless @machine_id

    @mutex.synchronize do
      ms = (Time.now.utc.to_f * 1000).to_i - EPOCH

      if ms == @last_ms
        @sequence = (@sequence + 1) & 0xFFF
        ms += 1 if @sequence.zero? # wait for next ms
      else
        @sequence = 0
        @last_ms = ms
      end

      id = (ms << 22) | (@machine_id << 12) | @sequence

      # Encode to Base58
      Approach2IdToBase58.encode(id)
    end
  end
end

# ---------------------------------------------------------------------------
# Benchmark runner
# ---------------------------------------------------------------------------

SAMPLE_SIZE = (ENV.fetch("SAMPLE_SIZE", "100_000").gsub("_", "")).to_i
WARMUP_SECONDS = ENV.fetch("WARMUP_SECONDS", "2").to_i
BENCHMARK_SECONDS = ENV.fetch("BENCHMARK_SECONDS", "5").to_i
FAKE_URLS = Array.new(SAMPLE_SIZE) { |i| "https://example.com/page/#{i}" }

def collision_test(label, size:)
  slugs = yield
  unique = slugs.to_set
  collisions = size - unique.size
  rate = (collisions.to_f / size * 100).round(4)
  puts "  #{label}: #{size} generated, #{collisions} collisions (#{rate}%)"
  { total: size, collisions: collisions, rate: rate }
end

puts "=" * 70
puts "Slug Generation Performance Benchmark"
puts "=" * 70
puts "Sample size: #{SAMPLE_SIZE}"
puts "Ruby: #{RUBY_VERSION} (#{RUBY_PLATFORM})"
puts

# ---------------------------------------------------------------------------
# Part 1: Generation throughput
# ---------------------------------------------------------------------------

puts "-" * 70
puts "Part 1: Generation Throughput (ops/sec)"
puts "-" * 70
puts

results = {}

Benchmark.bm(25) do |x|
  x.report("1. Random Base58") do
    SAMPLE_SIZE.times { Approach1RandomBase58.generate }
  end

  x.report("2. ID to Base58") do
    SAMPLE_SIZE.times { |i| Approach2IdToBase58.generate(i + 1) }
  end

  x.report("3. Hash Truncation") do
    SAMPLE_SIZE.times { |i| Approach3HashTruncation.generate(FAKE_URLS[i]) }
  end

  x.report("4. Hashids") do
    SAMPLE_SIZE.times { |i| Approach4Hashids.generate(i + 1) }
  end

  x.report("5. Snowflake") do
    SAMPLE_SIZE.times { Approach5Snowflake.generate }
  end
end

puts

# ---------------------------------------------------------------------------
# Part 2: Collision rate
# ---------------------------------------------------------------------------

puts "-" * 70
puts "Part 2: Collision Rate (#{SAMPLE_SIZE} slugs per approach)"
puts "-" * 70
puts

puts "Approach 1: Random Base58"
collision_test("  4-char only", size: SAMPLE_SIZE) do
  Array.new(SAMPLE_SIZE) { SecureRandom.base58(4) }
end
collision_test("  4-15 char (variable)", size: SAMPLE_SIZE) do
  Array.new(SAMPLE_SIZE) { Approach1RandomBase58.generate }
end
puts

puts "Approach 2: ID to Base58"
collision_test("  Sequential IDs", size: SAMPLE_SIZE) do
  Array.new(SAMPLE_SIZE) { |i| Approach2IdToBase58.generate(i + 1) }
end
puts

puts "Approach 3: Hash Truncation"
collision_test("  6-char hex", size: SAMPLE_SIZE) do
  Array.new(SAMPLE_SIZE) { |i| Approach3HashTruncation.generate(FAKE_URLS[i]) }
end
collision_test("  6-char hex (salted)", size: SAMPLE_SIZE) do
  Array.new(SAMPLE_SIZE) { |i| Approach3HashTruncation.generate_salted(FAKE_URLS[i], i) }
end
collision_test("  8-char hex", size: SAMPLE_SIZE) do
  Array.new(SAMPLE_SIZE) { |i| Approach3HashTruncation.generate(FAKE_URLS[i], length: 8) }
end
puts

puts "Approach 4: Hashids"
collision_test("  Sequential IDs", size: SAMPLE_SIZE) do
  Array.new(SAMPLE_SIZE) { |i| Approach4Hashids.generate(i + 1) }
end
puts

puts "Approach 5: Snowflake"
collision_test("  Time-based IDs", size: SAMPLE_SIZE) do
  Array.new(SAMPLE_SIZE) { Approach5Snowflake.generate }
end
puts

# ---------------------------------------------------------------------------
# Part 3: Average slug length
# ---------------------------------------------------------------------------

puts "-" * 70
puts "Part 3: Average Slug Length"
puts "-" * 70
puts

samples = {
  "Random Base58 (4-15)" => Array.new(10_000) { Approach1RandomBase58.generate },
  "ID to Base58 (1-100K)" => Array.new(10_000) { |i| Approach2IdToBase58.generate(i + 1) },
  "Hash Truncation (6)" => Array.new(10_000) { |i| Approach3HashTruncation.generate(FAKE_URLS[i]) },
  "Hashids" => Array.new(10_000) { |i| Approach4Hashids.generate(i + 1) },
  "Snowflake" => Array.new(10_000) { Approach5Snowflake.generate }
}

samples.each do |label, slugs|
  lengths = slugs.map(&:length)
  avg = (lengths.sum.to_f / lengths.length).round(2)
  min = lengths.min
  max = lengths.max
  puts "  #{label}: avg=#{avg}, min=#{min}, max=#{max}"
end
puts

puts "=" * 70
puts "Benchmark complete."
puts "=" * 70
