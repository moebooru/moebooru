require "net/http"

class Net::HTTP::Post
  def multipart=(params = [])
    boundary_token = "--multipart-boundary"
    self.content_type = "multipart/form-data; boundary=#{boundary_token}"

    self.body = ""
    params.each do |p|
      self.body += "--#{boundary_token}\r\n"
      self.body += "Content-Disposition: form-data; name=#{p[:name]}"
      self.body += "; filename=#{p[:filename]}" if p[:filename]
      self.body += "\r\n"
      if p[:binary]
        self.body += "Content-Transfer-Encoding: binary\r\n"

        mime_type = MiniMime.lookup_by_filename(p[:filename].to_s).try(:content_type)
        mime_type ||= "application/octet-stream"

        self.body += "Content-Type: #{mime_type}\r\n"
      end
      self.body += "\r\n#{p[:data]}\r\n"
    end
    self.body += "--#{boundary_token}--\r\n"
  end
end
