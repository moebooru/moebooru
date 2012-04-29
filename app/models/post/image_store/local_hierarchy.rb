module PostImageStoreMethods
  module LocalHierarchy
    def file_hierarchy
      "%s/%s" % [md5[0,2], md5[2,2]]
    end

    def file_path
      "#{Rails.root}/public/data/image/#{file_hierarchy}/#{file_name}"
    end

    def file_url
      if CONFIG["use_pretty_image_urls"] then
        CONFIG["url_base"] + "/image/#{md5}/#{url_encode(pretty_file_name)}.#{file_ext}"
      else
        CONFIG["url_base"] + "/data/image/#{file_hierarchy}/#{file_name}"
      end
    end

    def preview_path
      if status == "deleted"
        "#{Rails.root}/public/deleted-preview.png"
      elsif image?
        "#{Rails.root}/public/data/preview/#{file_hierarchy}/#{md5}.jpg"
      else
        "#{Rails.root}/public/download-preview.png"
      end
    end

    def sample_path
      "#{Rails.root}/public/data/sample/#{file_hierarchy}/" + CONFIG["sample_filename_prefix"] + "#{md5}.jpg"
    end

    def preview_url
      if image?
        CONFIG["url_base"] + "/data/preview/#{file_hierarchy}/#{md5}.jpg"
      else
        CONFIG["url_base"] + "/download-preview.png"
      end
    end

    def jpeg_path
      "#{Rails.root}/public/data/jpeg/#{file_hierarchy}/#{md5}.jpg"
    end

    def store_jpeg_url
      if CONFIG["use_pretty_image_urls"] then
        CONFIG["url_base"] + "/jpeg/#{md5}/#{url_encode(pretty_file_name({:type => :jpeg}))}.jpg"
      else
        CONFIG["url_base"] + "/data/jpeg/#{file_hierarchy}/#{md5}.jpg"
      end
    end

    def store_sample_url
      if CONFIG["use_pretty_image_urls"] then
        CONFIG["url_base"] + "/sample/#{md5}/#{url_encode(pretty_file_name({:type => :sample}))}.jpg"
      else
        CONFIG["url_base"] + "/data/sample/#{file_hierarchy}/" + CONFIG["sample_filename_prefix"] + "#{md5}.jpg"
      end
    end

    def delete_file
      FileUtils.rm_f(file_path)
      FileUtils.rm_f(preview_path) if image?
      FileUtils.rm_f(sample_path) if image?
      FileUtils.rm_f(jpeg_path) if image?
    end

    def move_file
      FileUtils.mkdir_p(File.dirname(file_path), :mode => 0775)
      FileUtils.mv(tempfile_path, file_path)
      FileUtils.chmod(0664, file_path)

      if image?
        FileUtils.mkdir_p(File.dirname(preview_path), :mode => 0775)
        FileUtils.mv(tempfile_preview_path, preview_path)
        FileUtils.chmod(0664, preview_path)
      end

      if File.exists?(tempfile_sample_path)
        FileUtils.mkdir_p(File.dirname(sample_path), :mode => 0775)
        FileUtils.mv(tempfile_sample_path, sample_path)
        FileUtils.chmod(0664, sample_path)
      end

      if File.exists?(tempfile_jpeg_path)
        FileUtils.mkdir_p(File.dirname(jpeg_path), :mode => 0775)
        FileUtils.mv(tempfile_jpeg_path, jpeg_path)
        FileUtils.chmod(0664, jpeg_path)
      end

      delete_tempfile
    end
  end
end
