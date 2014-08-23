require "multipart"
require "external_post"
require "cgi"

module Translate
  class ServerError < Exception; end

  def post(path, params, options = {})
    server = "http://ajax.googleapis.com"

    begin
      Timeout.timeout(10) do
        url = URI.parse(server)

        response = Net::HTTP.start(url.host, url.port) do |http|
          http.read_timeout = 10

          headers = {}
          headers["Referer"] = options[:referer] if options[:referer]

          request = Net::HTTP::Post.new(server + path, headers)
          request.multipart = params
          response = http.request(request)
        end
        resp = JSON.parse(response.body)

        # Undocumented: the API returns 404 if all translations return "could not reliably detect source language".
        if resp["responseStatus"] == 404 then
          return nil
        end

        if resp["responseStatus"] != 200 then
          raise ServerError, resp["responseDetails"]
        end
        return resp
      end
    rescue SocketError, SystemCallError
      raise ServerError, "Communication error"
    rescue Timeout::Error
      raise ServerError, "Timed out"
    end
  end

  # Given a string, attempt to translate into the specified languages.
  #
  #   translate("Hello world", :languages => ["es", "ja"])
  #
  # returns
  #
  #   {"es" => "hola mundo", "ja" => "こんにちは世界"}, "en"
  #
  # Not all languages may successfully translate.  If the translation API can't figure out the language,
  # no translations will be returned and the detected language will be "".
  def translate(s, options = {})
    languages = options[:languages]

    params = []
    params += [{ :name => "v", :data => "1.0" }]
    params += [{ :name => "format", :data => "html" }]
    params += [{ :name => "q", :data => s }]

    path = "/ajax/services/language/translate"
    languages.each do |lang|
      params += [{ :name => "langpair", :data => "|%s" % lang }]
    end

    #resp = Translate.request(path)
    resp = Translate.post(path, params, :referer => options[:referer])
    if resp.nil? then
      # We didn't get a usable response.
      return {}, ""
    end

    data = resp["responseData"]

    # The translate API is a bit inconsistent: it returns an array only when there's more than
    # one target language.  Handle both.
    translations = []
    if data.is_a?(Array) then
      data.each do |d|
        translations << d["responseData"]
      end
    else
        translations << data
    end

    result = {}
    source_lang = translations[0]["detectedSourceLanguage"]
    languages.each_index do |i|
      lang = languages[i]
      if lang == source_lang then
        # Guarantee that if the source and destination languages are the same, the output
        # is identical to the input.
        result[lang] = s
      else
        result[lang] = translations[i]["translatedText"]
      end
    end
    [result, source_lang]
  end

#  def request(path, options={})
#    server = 'http://ajax.googleapis.com'
#
#    begin
#      Timeout::timeout(10) {
#        url = URI.parse(server)
#
#        response = Net::HTTP.start(url.host, url.port) do |http|
#          http.read_timeout = 10
#          http.get(path)
#        end
#        resp = JSON.parse(response.body)
#        if resp["responseStatus"] != 200 then
#          raise ServerError, resp["responseDetails"]
#        end
#        return resp
#      }
#    rescue SocketError, SystemCallError => e
#      raise ServerError, "Communication error"
#    rescue Timeout::Error => e
#      raise ServerError, "Timed out"
#    end
#  end
#
#  def detect(s, options={})
#    path = '/ajax/services/language/detect?v=1.0&q=%s' % CGI::escape(s)
#    resp = Translate.request(path)
#
#    data = resp["responseData"]
#    return "??" if not data["isReliable"]
#    return data["language"]
#  end

  module_function :post, :translate
end
