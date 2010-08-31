require 'hpricot'

module ExtractUrls
  # Extract image URLs from HTML.
  def extract_image_urls(url, body)
    relative_url = url.gsub(/(https?:\/\/[^?]*)(\?.*)$*/, '\1');
    if relative_url !~ /\/$/ then relative_url += "/" end

    url_head = relative_url.gsub(/(https?:\/\/[^\/]+\/).*/, '\1');

    urls = []
    doc = Hpricot(body)
    doc.search("a[@href]").each do |param|
      href = param.attributes["href"]
      if href.nil? then next end
      if href !~ /\.(png|jpg|jpeg)$/i then next end
      if href =~ /https?:\/\// then
      elsif href =~ /^\// then
        href = url_head + href
      elsif href !~ /https?:\/\// then
        href = relative_url + href
      end

      urls.push(href)
    end
    return urls
  end

  module_function :extract_image_urls
end

