module Post::ImageStore
  module LocalFlatWithAmazonS3Backup
    def move_file
      FileUtils.mv(tempfile_path, file_path)
      FileUtils.chmod(0664, file_path)

      if image?
        FileUtils.mv(tempfile_preview_path, preview_path)
        FileUtils.chmod(0664, preview_path)
      end

      if File.exist?(tempfile_sample_path)
        FileUtils.mv(tempfile_sample_path, sample_path)
        FileUtils.chmod(0664, sample_path)
      end

      if File.exist?(tempfile_jpeg_path)
        FileUtils.mv(tempfile_jpeg_path, jpeg_path)
        FileUtils.chmod(0664, jpeg_path)
      end

      delete_tempfile

      base64_md5 = Base64.encode64(md5.unpack("a2" * (md5.size / 2)).map { |x| x.hex.chr }.join)

      AWS::S3::Base.establish_connection!(:access_key_id => CONFIG["amazon_s3_access_key_id"], :secret_access_key => CONFIG["amazon_s3_secret_access_key"])
      AWS::S3::S3Object.store(file_name, open(file_path, "rb"), CONFIG["amazon_s3_bucket_name"], :access => :public_read, "Content-MD5" => base64_md5)

      if image?
        AWS::S3::S3Object.store("preview/#{md5}.jpg", open(preview_path, "rb"), CONFIG["amazon_s3_bucket_name"], :access => :public_read)
      end

      if File.exist?(tempfile_sample_path)
        AWS::S3::S3Object.store("sample/" + CONFIG["sample_filename_prefix"] + "#{md5}.jpg", open(sample_path, "rb"), CONFIG["amazon_s3_bucket_name"], :access => :public_read)
      end

      if File.exist?(tempfile_jpeg_path)
        AWS::S3::S3Object.store("jpeg/#{md5}.jpg", open(jpeg_path, "rb"), CONFIG["amazon_s3_bucket_name"], :access => :public_read)
      end

      true
    end

    def file_path
      "#{Rails.root}/public/data/#{file_name}"
    end

    def file_url
      # "http://s3.amazonaws.com/" + CONFIG["amazon_s3_bucket_name"] + "/#{file_name}"
      CONFIG["url_base"] + "/data/#{file_name}"
    end

    def preview_path
      if image?
        "#{Rails.root}/public/data/preview/#{md5}.jpg"
      else
        "#{Rails.root}/public/download-preview.png"
      end
    end

    def sample_path
      "#{Rails.root}/public/data/sample/" + CONFIG["sample_filename_prefix"] + "#{md5}.jpg"
    end

    def preview_url
      #      if self.image?
      #        "http://s3.amazonaws.com/" + CONFIG["amazon_s3_bucket_name"] + "/preview/#{md5}.jpg"
      #      else
      #        "http://s3.amazonaws.com/" + CONFIG["amazon_s3_bucket_name"] + "/preview/download.png"
      #      end

      if status == "deleted"
        CONFIG["url_base"] + "/deleted-preview.png"
      elsif self.image?
        CONFIG["url_base"] + "/data/preview/#{md5}.jpg"
      else
        CONFIG["url_base"] + "/download-preview.png"
      end
    end

    def jpeg_path
      "#{Rails.root}/public/data/jpeg/#{md5}.jpg"
    end

    def store_jpeg_url
      CONFIG["url_base"] + "/data/jpeg/#{md5}.jpg"
    end

    def store_sample_url
      CONFIG["url_base"] + "/data/sample/" + CONFIG["sample_filename_prefix"] + "#{md5}.jpg"
    end

    def delete_file
      AWS::S3::Base.establish_connection!(:access_key_id => CONFIG["amazon_s3_access_key_id"], :secret_access_key => CONFIG["amazon_s3_secret_access_key"])
      AWS::S3::S3Object.delete(file_name, CONFIG["amazon_s3_bucket_name"])
      AWS::S3::S3Object.delete("preview/#{md5}.jpg", CONFIG["amazon_s3_bucket_name"])
      AWS::S3::S3Object.delete("sample/#{md5}.jpg", CONFIG["amazon_s3_bucket_name"])
      AWS::S3::S3Object.delete("jpeg/#{md5}.jpg", CONFIG["amazon_s3_bucket_name"])
      FileUtils.rm_f(file_path)
      FileUtils.rm_f(preview_path) if image?
      FileUtils.rm_f(sample_path) if image?
      FileUtils.rm_f(jpeg_path) if image?
    end
  end
end
