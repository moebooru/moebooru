module Post::ImageStore::Local2
  BASE_URL_SCHEME = CONFIG["secure"] ? "https" : "http"

  def file_hierarchy
    "%s/%s" % [md5[0, 2], md5[2, 2]]
  end

  def file_path
    "#{Rails.root}/public/data/image/#{file_hierarchy}/#{file_name}"
  end

  def preview_path
    if image?
      "#{Rails.root}/public/data/preview/#{file_hierarchy}/#{md5}.jpg"
    else
      "#{Rails.root}/public/download-preview.png"
    end
  end

  def sample_path
    "#{Rails.root}/public/data/sample/#{file_hierarchy}/" + CONFIG["sample_filename_prefix"] + "#{md5}.jpg"
  end

  def jpeg_path
    "#{Rails.root}/public/data/jpeg/#{file_hierarchy}/#{md5}.jpg"
  end

  def base_url(type = :files)
    return unless CONFIG[:file_hosts]

    "#{BASE_URL_SCHEME}://#{CONFIG[:file_hosts][type] || CONFIG[:file_hosts][:files]}"
  end

  def file_url
    if CONFIG["use_pretty_image_urls"] then
      "#{base_url}/image/#{md5}/#{pretty_file_name}.#{file_ext}"
    else
      "#{base_url}/data/image/#{file_hierarchy}/#{file_name}"
    end
  end

  def preview_url
    if status == "deleted"
      "#{base_url :assets}/deleted-preview.png"
    elsif image?
      "#{base_url :previews}/data/preview/#{file_hierarchy}/#{md5}.jpg"
    else
      "#{base_url :assets}/download-preview.png"
    end
  end

  def store_jpeg_url
    if CONFIG["use_pretty_image_urls"] then
      "#{base_url}/jpeg/#{md5}/#{pretty_file_name(:type => :jpeg)}.jpg"
    else
      "#{base_url}/data/jpeg/#{file_hierarchy}/#{md5}.jpg"
    end
  end

  def store_sample_url
    if CONFIG["use_pretty_image_urls"] then
      "#{base_url}/sample/#{md5}/#{pretty_file_name(:type => :sample)}.jpg"
    else
      "#{base_url}/data/sample/#{file_hierarchy}/" + CONFIG["sample_filename_prefix"] + "#{md5}.jpg"
    end
  end

  def frame_url(filename, _frame_number)
    "#{base_url}/data/frame/#{filename}"
  end

  def frame_preview_url(filename, _frame_number)
    "#{base_url}/data/frame-preview/#{filename}"
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
