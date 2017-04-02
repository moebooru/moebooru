require "base64"
require "net/https"

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
  def http_get_streaming(source, options = {}, &_block)
    max_size = options[:max_size] || CONFIG["max_image_size"]
    max_size = nil if max_size == 0 # unlimited

    # Decode data: URLs.
    if source =~ /^data:([^;]{1,100})(;[^;]{1,100})?,(.*)$/
      data = Base64.decode64(Regexp.last_match[3])
      return yield LocalData.new(data)
    end

    limit = 4

    loop do
      url = Addressable::URI.parse(source)
      url.host = url.normalized_host

      unless url.scheme == "http" || url.scheme == "https"
        raise SocketError, "URL must be HTTP or HTTPS"
      end

      # check if the request uri is not percent-encoded
      if url.request_uri.match /[^!*'();:@&=+$,\/?#\[\]ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789\-_.~%]/
        url.path = Addressable::URI.encode(url.path)
        url.query = Addressable::URI.encode(url.query)
      end

      # Addressable doesn't fill in port data if not explicitly given.
      unless url.port
        url.port = url.scheme == "https" ? 443 : 80
      end

      http = Net::HTTP.new url.host, url.port
      if url.scheme == "https"
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      end
      http.start do
        http.read_timeout = 10

        headers = {
          "User-Agent" => "#{CONFIG["app_name"]}/#{CONFIG["version"]}",
          "Referer" => source
        }

        if source =~ /(pixiv\.net|pximg\.net)/
          headers["Referer"] = "http://www.pixiv.net"

          # Don't download the small version
          if source =~ %r{(/img/.+?/.+?)_m.+$}
            match = Regexp.last_match[1]
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
            if limit == 0
              raise SocketError, "Too many redirects"
            end
            new_url = Addressable::URI.parse(res["location"])
            new_url = (url + new_url) if new_url.relative?

            source = new_url.to_str
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
