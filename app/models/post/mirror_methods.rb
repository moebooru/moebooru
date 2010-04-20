require "mirror"

class MirrorError < Exception ; end

module PostMirrorMethods
  def upload_to_mirrors
    return if is_warehoused
    return if self.status == "deleted"

    files_to_copy = [self.file_path]
    files_to_copy << self.preview_path if self.image?
    files_to_copy << self.sample_path if self.has_sample?
    files_to_copy << self.jpeg_path if self.has_jpeg?
    files_to_copy = files_to_copy.uniq

    # CONFIG[:data_dir] is equivalent to our local_base.
    local_base = "#{RAILS_ROOT}/public/data/"

    CONFIG["mirrors"].each { |mirror|
      remote_user_host = "#{mirror[:user]}@#{mirror[:host]}"
      remote_dirs = []
      files_to_copy.each { |file|
        remote_filename = file[local_base.length, file.length]
        remote_dir = File.dirname(remote_filename)
        remote_dirs << mirror[:data_dir] + "/" + File.dirname(remote_filename)
      }

      # Create all directories in one go.
      system("/usr/bin/ssh", "-o", "Compression=no", "-o", "BatchMode=yes",
             remote_user_host, "mkdir -p #{remote_dirs.uniq.join(" ")}")
    }

    begin
      files_to_copy.each { |file|
        Mirrors.copy_file_to_mirrors(file)
      }
    rescue MirrorError => e
      # The post might be deleted while it's uploading.  Check the post status after
      # an error.
      self.reload
      raise if self.status != "deleted"
    end

    # This might take a while.  Rather than hold a transaction, just reload the post
    # after uploading.
    self.reload
    self.update_attributes(:is_warehoused => true)
  end
end
