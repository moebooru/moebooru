require 'nokogiri'

module ExtractUrls
  # Extract image URLs from HTML.
  def extract_image_urls(url, body)
    urls = []
    Nokogiri::HTML(body).xpath('//a[@href]').each do |link|
      urls += [Addressable::URI.join("#{url}/", link[:href]).normalize.to_s] if link[:href] =~ /\.(png|jpe?g)\z/i
    end
    return urls
  end

  module_function :extract_image_urls
end

