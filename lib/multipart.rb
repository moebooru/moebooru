require "net/http"
require "mime/types"

class Net::HTTP::Post
  def multipart=(params = [])
    boundary_token = "--multipart-boundary"
    self.content_type = "multipart/form-data; boundary=#{boundary_token}"

    self.body = ""
    params.each { |p|
      self.body += "--#{boundary_token}\r\n"
      self.body += "Content-Disposition: form-data; name=#{p[:name]}"
      self.body += "; filename=#{p[:filename]}" if p[:filename]
      self.body += "\r\n"
      if p[:binary] then
        self.body += "Content-Transfer-Encoding: binary\r\n"

        mime_type = "application/octet-stream"
        if p[:filename]
          mime_types = MIME::Types.of(p[:filename])
          mime_type = mime_types.first.content_type unless mime_types.empty?
        end

        self.body += "Content-Type: #{mime_type}\r\n"
      end
      self.body += "\r\n#{p[:data].to_s}\r\n"
    }
    self.body += "--#{boundary_token}--\r\n"
  end
end
