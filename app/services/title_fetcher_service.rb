class TitleFetcherService
  TIMEOUT = 10
  MAX_BODY_SIZE = 1.megabyte

  def self.call(url)
    raise ArgumentError, "URL cannot be blank" if url.blank?

    uri = URI.parse(url)
    body = +""

    # Net::HTTP does not follow redirects by default, preventing SSRF via redirect to internal addresses.
    Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
                     read_timeout: TIMEOUT, open_timeout: TIMEOUT) do |http|
      http.request_get(uri.request_uri) do |response|
        return nil unless response.is_a?(Net::HTTPSuccess)

        response.read_body do |chunk|
          body << chunk
          if body.bytesize > MAX_BODY_SIZE
            Rails.logger.warn("[TitleFetcherService] Response for #{url} exceeds #{MAX_BODY_SIZE} bytes, truncating")
            break
          end
        end
      end
    end

    doc = Nokogiri::HTML(body)
    title = doc.at_css("title")&.text&.strip
    title.presence
  rescue ArgumentError
    raise
  rescue StandardError => e
    Rails.logger.warn("[TitleFetcherService] Failed to fetch title for #{url}: #{e.message}")
    nil
  end
end
