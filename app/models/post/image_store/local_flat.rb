module Post::ImageStore
  module LocalFlat
    def file_path
      "#{Rails.root}/public/data/#{file_name}"
    end

    def file_url
      if CONFIG["use_pretty_image_urls"]
        CONFIG["url_base"] + "/image/#{md5}/#{url_encode(pretty_file_name)}.#{file_ext}"
      else
        CONFIG["url_base"] + "/data/#{file_name}"
      end
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
      if status == "deleted"
        CONFIG["url_base"] + "/deleted-preview.png"
      elsif image?
        CONFIG["url_base"] + "/data/preview/#{md5}.jpg"
      else
        CONFIG["url_base"] + "/download-preview.png"
      end
    end

    def jpeg_path
      "#{Rails.root}/public/data/jpeg/#{md5}.jpg"
    end

    def store_jpeg_url
      if CONFIG["use_pretty_image_urls"]
        CONFIG["url_base"] + "/jpeg/#{md5}/#{url_encode(pretty_file_name(:type => :jpeg))}.jpg"
      else
        CONFIG["url_base"] + "/data/jpeg/#{md5}.jpg"
      end
    end

    def store_sample_url
      if CONFIG["use_pretty_image_urls"]
        path = "/sample/#{md5}/#{url_encode(pretty_file_name(:type => :sample))}.jpg"
      else
        path = "/data/sample/" + CONFIG["sample_filename_prefix"] + "#{md5}.jpg"
      end

      CONFIG["url_base"] + path
    end

    def frame_url(filename, _frame_number)
      "#{CONFIG["url_base"]}/data/frame/#{filename}"
    end

    def frame_preview_url(filename, _frame_number)
      "#{CONFIG["url_base"]}/data/frame-preview/#{filename}"
    end

    def delete_file
      FileUtils.rm_f(file_path)
      FileUtils.rm_f(preview_path) if image?
      FileUtils.rm_f(sample_path) if image?
      FileUtils.rm_f(jpeg_path) if image?
    end

    def move_file
      FileUtils.mv(tempfile_path, file_path)
      FileUtils.chmod(0664, file_path)

      if image?
        FileUtils.mkdir_p(File.dirname(preview_path), :mode => 0775)
        FileUtils.mv(tempfile_preview_path, preview_path)
        FileUtils.chmod(0664, preview_path)
      end

      if File.exist?(tempfile_sample_path)
        FileUtils.mkdir_p(File.dirname(sample_path), :mode => 0775)
        FileUtils.mv(tempfile_sample_path, sample_path)
        FileUtils.chmod(0664, sample_path)
      end

      if File.exist?(tempfile_jpeg_path)
        FileUtils.mkdir_p(File.dirname(jpeg_path), :mode => 0775)
        FileUtils.mv(tempfile_jpeg_path, jpeg_path)
        FileUtils.chmod(0664, jpeg_path)
      end

      delete_tempfile
    end
  end
end
