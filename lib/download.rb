module Danbooru
  # Download the given URL, following redirects; once we have the result, yield the request.
  def http_get_streaming(source, options = {}, &block)
    max_size = options[:max_size] || CONFIG["max_image_size"]
    max_size = nil if max_size == 0 # unlimited

    limit = 4

    while true
      url = URI.parse(source)

      unless url.is_a?(URI::HTTP)
        raise SocketError, "URL must be HTTP"
      end

      Net::HTTP.start(url.host, url.port) do |http|
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

