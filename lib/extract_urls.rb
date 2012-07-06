require 'nokogiri'

module ExtractUrls
  # Extract image URLs from HTML.
  def extract_image_urls(url, body)
    urls = []
    Nokogiri::HTML(body).xpath('//a[@href]').each do |link|
      urls += [URI.join(url, link[:href]).to_s] if link[:href] =~ /\.(png|jpg|jpeg)\z/i
    end
    return urls
  end

  module_function :extract_image_urls
end

