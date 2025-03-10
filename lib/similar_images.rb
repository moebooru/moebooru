module SimilarImages
  def get_services(services)
    services = services
    services ||= "local"
    if services == "all"
      services = CONFIG["image_service_list"].map { |a, _b| a }
    else
      services = services.split(/,/)
    end

    services.each_index { |i| if services[i] == "local" then services[i] = CONFIG["local_image_service"] end }
    services
  end

  def similar_images(options = {})
    errors = {}

    local_service = CONFIG["local_image_service"]

    services = options[:services]

    services_by_server = {}
    services.each do |service|
      server = CONFIG["image_service_list"][service]
      unless server
        errors[""] = { services: [ service ], message: "%s is an unknown service" % service }
        next
      end
      services_by_server[server] = [] unless services_by_server[server]
      services_by_server[server] += [ service ]
    end

    # If the source is a local post, read the preview and send it with the request.
    if options[:type] == :post
      source_file = File.open(options[:source].preview_path, "rb") { |file| file.read }
      source_filename = options[:source].preview_path
    elsif options[:type] == :file
      source_file = options[:source].read
      source_filename = options[:source_filename]
    end

    server_threads = []
    server_responses = {}
    services_by_server.map do |server, services_list|
      server_threads.push Thread.new {
        if options[:type] == :url
          search_url = options[:source]
        end
        if options[:type] == :post && CONFIG["image_service_local_searches_use_urls"]
          search_url = options[:source].preview_url
        end

        params = []
        if search_url
          params << [ "url", search_url ]
        else
          params << [ "file", source_file, filename: File.basename(source_filename) ]
        end

        services_list.each do |s|
          params << [ "service[]", s ]
        end
        params << [ "forcegray", "on" ] if options[:forcegray] == "1"

        begin
          Timeout.timeout(10) do
            url = URI.parse(server)

            http_options = {}

            if url.scheme == "https"
              http_options[:use_ssl] = true
              http_options[:verify_mode] = OpenSSL::SSL::VERIFY_NONE
            end

            Net::HTTP.start(url.host, url.port, nil, nil, nil, nil, http_options) do |http|
              http.read_timeout = 10

              request = Net::HTTP::Post.new(server)
              request.set_form params, "multipart/form-data"
              response = http.request(request)
              server_responses[server] = response.body
            end
          end
        rescue SocketError, SystemCallError => e
          errors[server] = { message: e }
        rescue Timeout::Error
          errors[server] = { message: "Timed out" }
        end
      }
    end
    server_threads.each(&:join)

    posts = []
    posts_external = []
    similarity = {}
    next_id = 1
    server_responses.map do |server, xml|
      doc = begin
        Nokogiri::XML xml.to_valid_utf8
      rescue
        errors[server] = { message: "parse error" }
        next
      end

      unless doc.root
        errors[server] = { message: "invalid response" }
        next
      end

      if doc.root.name == "error"
        errors[server] = { message: doc.root[:message] }
        next
      end

      threshold = (options[:threshold] || doc.root[:threshold]).to_f

      doc.search("matches/match").each do |element|
        if element[:sim].to_f >= threshold && element[:sim].to_f > 0
          service = element[:service]
          image = element.search("[id]").first

          id = image[:id]
          md5 = element[:md5]

          if service == local_service
            post = Post.find_by(id: id)
            unless post.nil? || post == options[:source]
              posts += [ post ]
              similarity[post] = element[:sim].to_f
            end
          elsif service
            post = ExternalPost.new
            post.id = "#{next_id}"
            next_id += 1
            post.md5 = md5
            post.preview_url = element[:preview]
            if service == "gelbooru.com" # hack
              post.url = "http://" + service + "/index.php?page=post&s=view&id=" + id
            elsif service == "e-shuushuu.net" # hack
              post.url = "http://" + service + "/image/" + id + "/"
            else
              post.url = "http://" + service + "/post/show/" + id
            end
            post.sample_url = image[:sample_url] || post.url
            post.service = service
            post.width = element[:width].to_i
            post.height = element[:height].to_i
            post.tags = image[:tags] || ""
            post.rating = image[:rating] || "s"
            posts_external += [ post ]

            similarity[post] = element[:sim].to_f
          end
        end
      end
    end

    posts = posts.sort { |a, b| similarity[b] <=> similarity[a] }
    posts_external = posts_external.sort { |a, b| similarity[b] <=> similarity[a] }

    errors.map do |server, error|
      unless error[:services]
        error[:services] = services_by_server[server] rescue server
      end
    end
    ret = { posts: posts, posts_external: posts_external, similarity: similarity, services: services, errors: errors }
    if options[:type] == :post
      ret[:source] = options[:source]
      ret[:similarity][options[:source]] = "Original"
      ret[:search_id] = ret[:source].id
    else
      post = ExternalPost.new
      #      post.md5 = md5
      post.preview_url = options[:source_thumb]
      post.url = options[:full_url] || options[:url] || options[:source_thumb]
      post.id = "source"
      post.service = ""
      post.tags = ""
      post.rating = "q"
      ret[:search_id] = "source"

      # Don't include the source URL if it's a data: url; it can be very large and isn't useful.
      if post.url.slice(0, 5) == "data:"
        post.url = ""
      end

      imgsize = Moebooru::ImageSizeExif.data(source_file)
      source_width = imgsize[:width]
      source_height = imgsize[:height]

      # Since we lose access to the original image when we redirect to a saved search,
      # the original dimensions can be passed as parameters so we can still display
      # the original size.  This can also be used by user scripts to include the
      # size of the real image when a thumbnail is passed.
      post.width = options[:width] || source_width
      post.height = options[:height] || source_height

      ret[:external_source] = post
      ret[:similarity][post] = "Original"
    end

    ret
  end

  SEARCH_CACHE_DIR = "#{Rails.root}/public/data/search"
  # Save a file locally to be searched for.  Returns the path to the saved file, and
  # the search ID which can be passed to find_saved_search.
  def save_search
    begin
      FileUtils.mkdir_p(SEARCH_CACHE_DIR, mode: 0775)

      tempfile_path = "#{SEARCH_CACHE_DIR}/#{SecureRandom.random_number(2**32)}.upload"
      File.open(tempfile_path, "wb") { |f| yield f }

      # Use the resizer to validate the file and convert it to a thumbnail-size JPEG.
      imgsize = Moebooru::ImageSizeExif.path(tempfile_path)
      if imgsize[:type].blank?
        raise Moebooru::Resizer::ResizeError, "Unrecognized image format"
      end

      ret = {}
      ret[:original_width] = imgsize[:width]
      ret[:original_height] = imgsize[:height]
      size = Moebooru::Resizer.reduce_to({ width: ret[:original_width], height: ret[:original_height] }, width: 150, height: 150)
      ext = imgsize[:type].gsub(/jpeg/i, "jpg").downcase

      tempfile_path_resize = "#{tempfile_path}.2"
      Moebooru::Resizer.resize(ext, tempfile_path, tempfile_path_resize, size, 95)
      FileUtils.mv(tempfile_path_resize, tempfile_path)

      md5 = Moebooru::Hasher.compute_one(tempfile_path, :md5)
      id = "#{md5}.#{ext}"
      file_path = "#{SEARCH_CACHE_DIR}/#{id}"

      FileUtils.mv(tempfile_path, file_path)
      FileUtils.chmod(0664, file_path)
    rescue
      FileUtils.rm_f(file_path) if file_path
      raise
    ensure
      FileUtils.rm_f(tempfile_path) if tempfile_path
      FileUtils.rm_f(tempfile_path_resize) if tempfile_path_resize
    end

    ret[:file_path] = file_path
    ret[:search_id] = id
    ret
  end

  def valid_saved_search(id)
    id =~ /\A[a-zA-Z0-9]{32}\.[a-z]+\Z/
  end

  # Find a saved file.
  def find_saved_search(id)
    unless valid_saved_search(id) then return nil end

    file_path = "#{SEARCH_CACHE_DIR}/#{id}"
    unless File.exist?(file_path)
      return nil
    end

    # Touch the file to delay its deletion.
    File.open(file_path, "a")
    file_path
  end

  # Delete old searches.
  def cull_old_searches
    Dir.foreach(SEARCH_CACHE_DIR) do |path|
      next unless valid_saved_search(path)

      file = "#{SEARCH_CACHE_DIR}/#{path}"
      mtime = File.mtime(file)
      age = Time.now - mtime
      if age > 60 * 60 * 24
        FileUtils.rm_f(file)
      end
    end
  end

  module_function :similar_images, :get_services, :find_saved_search, :cull_old_searches, :save_search, :valid_saved_search
end
