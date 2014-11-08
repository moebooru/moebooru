module Mirrors
  class MirrorError < Exception; end

  def ssh_open_pipe(mirror, command, timeout = 30)
    remote_user_host = "#{mirror[:user]}@#{mirror[:host]}"
    ret = nil
    IO.popen("/usr/bin/ssh -o ServerAliveInterval=30 -o Compression=no -o BatchMode=yes -o ConnectTimeout=#{timeout} #{remote_user_host} '#{command}'") do |f|
      ret = yield(f)
    end
    if ($CHILD_STATUS & 0xFF) != 0
      raise MirrorError, "Command \"%s\" to %s exited with signal %i" % [command, mirror[:host], $CHILD_STATUS & 0xFF]
    end
    if ($CHILD_STATUS >> 8) != 0
      raise MirrorError, "Command \"%s\" to %s exited with status %i" % [command, mirror[:host], $CHILD_STATUS >> 8]
    end
    ret
  end
  module_function :ssh_open_pipe

  def filter_mirror_list(options)
    results = []
    CONFIG["mirrors"].each do |mirror|
      next if options[:previews_only] != mirror[:previews_only]
      results << mirror
    end

    results
  end
  module_function :filter_mirror_list

  def create_mirror_paths(dirs, options = {})
    dirs = dirs.uniq

    target_mirrors = filter_mirror_list(options)
    target_mirrors.each do |mirror|
      remote_user_host = "#{mirror[:user]}@#{mirror[:host]}"
      remote_dirs = []
      dirs.each do |dir|
        remote_dirs << mirror[:data_dir] + "/" + dir
      end

      # Create all directories in one go.
      system("/usr/bin/ssh", "-o", "Compression=no", "-o", "BatchMode=yes",
             remote_user_host, "mkdir -p #{remote_dirs.uniq.join(" ")}")
    end
  end
  module_function :create_mirror_paths

  # Copy a file to all mirrors.  file is an absolute path which must be
  # located in public/data; the files will land in the equivalent public/data
  # on each mirror.
  #
  # If options[:previews_only] is true, copy only to :previews_only mirrors; otherwise
  # copy only to others.
  #
  # Because we have no mechanism for indicating that a file is only available on
  # certain mirrors, if any mirror fails to upload, MirrorError will be thrown
  # and the file should be treated as completely unwarehoused.
  def copy_file_to_mirrors(file, options = {})
    # CONFIG[:data_dir] is equivalent to our local_base.
    local_base = "#{Rails.root}/public/data/"
    options = { :timeout => 30 }.merge(options)

    if file[0, local_base.length] != local_base
      raise "Invalid filename to mirror: \"%s" % file
    end

    expected_md5 = File.open(file, "rb") { |fp| Digest::MD5.hexdigest(fp.read) }

    target_mirrors = filter_mirror_list(options)
    target_mirrors.each do |mirror|
      remote_user_host = "#{mirror[:user]}@#{mirror[:host]}"
      remote_filename = "#{mirror[:data_dir]}/#{file[local_base.length, file.length]}"

      # Tolerate a few errors in case of communication problems.
      retry_count = 0

      begin
        # Check if the file is already mirrored before we spend time uploading it.
        # Linux needs md5sum; FreeBSD needs md5 -q.
        actual_md5 = Mirrors.ssh_open_pipe(mirror,
                                           "if [ -f #{remote_filename} ]; then (which md5sum >/dev/null) && md5sum #{remote_filename} || md5 -q #{remote_filename}; fi",
                                           timeout = options[:timeout]) { |f| f.gets }
        if actual_md5 =~ /^[0-9a-f]{32}/
          actual_md5 = actual_md5.slice(0, 32)
          if expected_md5 == actual_md5
            next
          end
        end

        unless system("/usr/bin/scp", "-pq", "-o", "Compression no", "-o", "BatchMode=yes",
                      "-o", "ConnectTimeout=%i" % timeout,
                      file, "#{remote_user_host}:#{remote_filename}")
          raise MirrorError, "Error copying #{file} to #{remote_user_host}:#{remote_filename}"
        end

        # Don't trust scp; verify the files.
        actual_md5 = Mirrors.ssh_open_pipe(mirror, "if [ -f #{remote_filename} ]; then (which md5sum >/dev/null) && md5sum #{remote_filename} || md5 -q #{remote_filename}; fi") { |f| f.gets }
        if actual_md5 !~ /^[0-9a-f]{32}/
          raise MirrorError, "Error verifying #{remote_user_host}:#{remote_filename}: #{actual_md5}"
        end

        actual_md5 = actual_md5.slice(0, 32)

        if expected_md5 != actual_md5
          raise MirrorError, "Verifying #{remote_user_host}:#{remote_filename} failed: got #{actual_md5}, expected #{expected_md5}"
        end
      rescue MirrorError
        retry_count += 1
        raise if retry_count == 3

        retry
      end
    end
  end
  module_function :copy_file_to_mirrors

  # Return a URL prefix for a file.  If not warehoused, always returns the main
  # server.  If a seed is specified, seeds the server selection; otherwise, each
  # IP will always use the same server.
  #
  # If :zipfile is set, ignore mirrors with the :nozipfile flag.
  if CONFIG["image_store"] == :remote_hierarchy
    def select_main_image_server
      return CONFIG["url_base"] if !CONFIG["image_servers"] || CONFIG["image_servers"].empty?
      raise 'CONFIG["url_base"] is set incorrectly; please see config/default_config.rb' if CONFIG["image_servers"][0].class == String

      CONFIG["image_servers"][0][:server]
    end

    def select_image_server(is_warehoused, seed = 0, options = {})
      return CONFIG["url_base"] if !CONFIG["image_servers"] || CONFIG["image_servers"].empty?
      raise 'CONFIG["url_base"] is set incorrectly; please see config/default_config.rb' if CONFIG["image_servers"][0].class == String

      unless is_warehoused
        # return CONFIG["url_base"]
        return CONFIG["image_servers"][0][:server]
      end

      mirrors = CONFIG["image_servers"]
      if options[:preview]
        mirrors =  mirrors.select do |mirror|
          mirror[:nopreview] != true
        end
      end

      unless options[:preview]
        mirrors =  mirrors.select do |mirror|
          mirror[:previews_only] != true
        end
      end

      if options[:zipfile]
        mirrors =  mirrors.select do |mirror|
          mirror[:nozipfile] != true
        end
      end

      raise "No usable mirrors" if mirrors.empty?

      total_weights = 0
      mirrors.each { |s| total_weights += s[:traffic] }

      seed += Thread.current["danbooru-ip_addr_seed"] || 0
      seed %= total_weights

      server = nil
      mirrors.each do |s|
        w = s[:traffic]
        if seed < w
          server = s
          break
        end

        seed -= w
      end
      server ||= mirrors[0]

      # If this server has aliases, and an ID has been specified, pick a random server alias
      # with the ID as a seed so we always use the same server name for the same image.
      if !options[:id].nil? && !server[:aliases].nil? && options[:use_aliases]
        server_count = server[:aliases].length + 1
        server_index = options[:id] % server_count
        if server_index == 0
          return server[:server]
        else
          return server[:aliases][server_index - 1]
        end
      end

      server[:server]
    end
  else
    def select_main_image_server
      CONFIG["url_base"]
    end

    def select_image_server(_is_warehoused, _seed = 0, _options = {})
      CONFIG["url_base"]
    end
  end
  module_function :select_main_image_server
  module_function :select_image_server
end
