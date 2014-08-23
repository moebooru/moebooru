module Post::ImageStore
  module AmazonS3
    def move_file
      begin
        base64_md5 = Base64.encode64(self.md5.unpack("a2" * (self.md5.size / 2)).map { |x| x.hex.chr }.join)

        AWS::S3::Base.establish_connection!(:access_key_id => CONFIG["amazon_s3_access_key_id"], :secret_access_key => CONFIG["amazon_s3_secret_access_key"])
        AWS::S3::S3Object.store(file_name, open(self.tempfile_path, "rb"), CONFIG["amazon_s3_bucket_name"], :access => :public_read, "Content-MD5" => base64_md5, "Cache-Control" => "max-age=315360000")

        if image?
          AWS::S3::S3Object.store("preview/#{md5}.jpg", open(self.tempfile_preview_path, "rb"), CONFIG["amazon_s3_bucket_name"], :access => :public_read, "Cache-Control" => "max-age=315360000")
        end

        if File.exist?(tempfile_sample_path)
          AWS::S3::S3Object.store("sample/" + CONFIG["sample_filename_prefix"] + "#{md5}.jpg", open(self.tempfile_sample_path, "rb"), CONFIG["amazon_s3_bucket_name"], :access => :public_read, "Cache-Control" => "max-age=315360000")
        end

        if File.exist?(tempfile_jpeg_path)
          AWS::S3::S3Object.store("jpeg/#{md5}.jpg", open(self.tempfile_jpeg_path, "rb"), CONFIG["amazon_s3_bucket_name"], :access => :public_read, "Cache-Control" => "max-age=315360000")
        end

        return true
      ensure
        self.delete_tempfile()
      end
    end

    def file_url
      "http://s3.amazonaws.com/" + CONFIG["amazon_s3_bucket_name"] + "/#{file_name}"
    end

    def preview_url
      if self.image?
        "http://s3.amazonaws.com/" + CONFIG["amazon_s3_bucket_name"] + "/preview/#{md5}.jpg"
      else
        "http://s3.amazonaws.com/" + CONFIG["amazon_s3_bucket_name"] + "/preview/download.png"
      end
    end

    def store_sample_url
      "http://s3.amazonaws.com/" + CONFIG["amazon_s3_bucket_name"] + "/sample/deleted.png"
    end

    def store_jpeg_url
      "http://s3.amazonaws.com/" + CONFIG["amazon_s3_bucket_name"] + "/jpeg/deleted.png"
    end

    def delete_file
      AWS::S3::Base.establish_connection!(:access_key_id => CONFIG["amazon_s3_access_key_id"], :secret_access_key => CONFIG["amazon_s3_secret_access_key"])
      AWS::S3::S3Object.delete(file_name, CONFIG["amazon_s3_bucket_name"])
      AWS::S3::S3Object.delete("preview/#{md5}.jpg", CONFIG["amazon_s3_bucket_name"])
      AWS::S3::S3Object.delete("sample/#{md5}.jpg", CONFIG["amazon_s3_bucket_name"])
      AWS::S3::S3Object.delete("jpeg/#{md5}.jpg", CONFIG["amazon_s3_bucket_name"])
    end
  end
end
