module Danbooru
  # for .diff
  TAG_DEL = "<del>"
  TAG_INS = "<ins>"
  TAG_DEL_CLOSE = "</del>"
  TAG_INS_CLOSE = "</ins>"
  TAG_NEWLINE = "↲\n"
  TAG_BREAK = "<br>\n"

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

  # Produce a formatted page that shows the difference between two versions of a page.
  def diff(old, new)
    pattern = Regexp.new('(?:<.+?>)|(?:\p{Word}+)|(?:[ \t]+)|(?:\r?\n)|(?:.+?)')

    thisarr = old.scan(pattern)
    otharr = new.scan(pattern)

    cbo = Diff::LCS::ContextDiffCallbacks.new
    diffs = thisarr.diff(otharr, cbo)

    escape_html = lambda { |str| str.gsub(/&/, "&amp;").gsub(/</, "&lt;").gsub(/>/, "&gt;") }

    output = thisarr
    output.each { |q| q.replace(escape_html[q]) }

    diffs.reverse_each do |hunk|
      newchange = hunk.max { |a, b| a.old_position <=> b.old_position }
      newstart = newchange.old_position
      oldstart = hunk.min { |a, b| a.old_position <=> b.old_position }.old_position

      if newchange.action == "+"
        output.insert(newstart, TAG_INS_CLOSE)
      end

      hunk.reverse_each do |chg|
        case chg.action
        when "-"
          oldstart = chg.old_position
          output[chg.old_position] = TAG_NEWLINE if chg.old_element.match(/^\r?\n$/)
        when "+"
          if chg.new_element.match(/^\r?\n$/)
            output.insert(chg.old_position, TAG_NEWLINE)
          else
            output.insert(chg.old_position, "#{escape_html[chg.new_element]}")
          end
        end
      end

      if newchange.action == "+"
        output.insert(newstart, TAG_INS)
      end

      if hunk[0].action == "-"
        output.insert((newstart == oldstart || newchange.action != "+") ? newstart + 1 : newstart, TAG_DEL_CLOSE)
        output.insert(oldstart, TAG_DEL)
      end
    end

    output.join.gsub(/\r?\n/, TAG_BREAK)
  end

  module_function :diff
end
