require "mirror"

class MirrorError < Exception; end

module Post::MirrorMethods
  # On :normal, upload all files to all mirrors except :previews_only ones.
  # On :previews_only, upload previews to previews_only mirrors.
  def upload_to_mirrors_internal(mode = :normal)
    files_to_copy = []
    if mode != :previews_only
      files_to_copy << file_path
      files_to_copy << sample_path if self.has_sample?
      files_to_copy << jpeg_path if self.has_jpeg?
    end
    files_to_copy << preview_path if self.image?
    files_to_copy = files_to_copy.uniq

    # CONFIG[:data_dir] is equivalent to our local_base.
    local_base = "#{Rails.root}/public/data/"

    dirs = []
    files_to_copy.each do |file|
      dirs << File.dirname(file[local_base.length, file.length])
    end

    options = {}
    if mode == :previews_only
      options[:previews_only] = true
    end

    Mirrors.create_mirror_paths(dirs, options)
    files_to_copy.each do |file|
      Mirrors.copy_file_to_mirrors(file, options)
    end
  end

  def upload_to_mirrors
    return if is_warehoused
    return if status == "deleted"

    begin
      upload_to_mirrors_internal(:normal)
      upload_to_mirrors_internal(:previews_only)
    rescue MirrorError
      # The post might be deleted while it's uploading.  Check the post status after
      # an error.
      reload
      raise if status != "deleted"
      return
    end

    # This might take a while.  Rather than hold a transaction, just reload the post
    # after uploading.
    reload
    update(:is_warehoused => true)
  end
end
