require "base64"
require 'net/https'

# This simulates an http.request_get response, for data: URLs.
class LocalData
  def initialize(data)
    @data = data
  end
  def read_body
    yield @data
  end
end

module Danbooru
  # Download the given URL, following redirects; once we have the result, yield the request.
  def http_get_streaming(source, options = {}, &block)
    max_size = options[:max_size] || CONFIG["max_image_size"]
    max_size = nil if max_size == 0 # unlimited

    # Decode data: URLs.
    if source =~ /^data:([^;]{1,100})(;[^;]{1,100})?,(.*)$/
      data = Base64.decode64($3)
      return yield LocalData.new(data)
    end

    limit = 4

    while true
      url = Addressable::URI.parse(source).normalize

      unless url.scheme == 'http'
        raise SocketError, "URL must be HTTP"
      end

      http = Net::HTTP.new url.host, url.port
      if url.scheme == 'https'
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      end
      http.start do
        http.read_timeout = 10

        headers = {
          "User-Agent" => "#{CONFIG["app_name"]}/#{CONFIG["version"]}",
          "Referer" => source
        }

        if source =~ /pixiv\.net/
          headers["Referer"] = "http://www.pixiv.net"

          # Don't download the small version
          if source =~ %r!(/img/.+?/.+?)_m.+$!
            match = $1
            source.sub!(match + "_m", match)
          end
        end

        http.request_get(url.request_uri, headers) do |res|
          case res
          when Net::HTTPSuccess then
            if max_size
              len = res["Content-Length"]
              raise SocketError, "File is too large (#{len} bytes)" if len && len.to_i > max_size
            end

            return yield(res)

          when Net::HTTPRedirection then
            if limit == 0 then
              raise SocketError, "Too many redirects"
            end
            source = res["location"]
            limit -= 1

          else
            raise SocketError, "HTTP error code: #{res.code} #{res.message}"
          end
        end
      end
    end
  end

  module_function :http_get_streaming
end

