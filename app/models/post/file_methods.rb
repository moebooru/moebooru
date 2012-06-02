require "download"
require "zlib"

# These are methods dealing with getting the image and generating the thumbnail.
# It works in conjunction with the image_store methods. Since these methods have 
# to be called in a specific order, they've been bundled into one module.
module PostFileMethods
  def self.included(m)
    m.before_validation :download_source, :on => :create
    m.before_validation :ensure_tempfile_exists, :on => :create
    m.before_validation :determine_content_type, :on => :create
    m.before_validation :validate_content_type, :on => :create
    m.before_validation :strip_exif, :on => :create
    m.before_validation :generate_hash, :on => :create
    m.before_validation :set_image_dimensions, :on => :create
    m.before_validation :set_image_status, :on => :create
    m.before_validation :check_pending_count, :on => :create
    m.before_validation :generate_sample, :on => :create
    m.before_validation :generate_jpeg, :on => :create
    m.before_validation :generate_preview, :on => :create
    m.before_validation :move_file, :on => :create
  end
  attr_accessor :_tempfile_prefix

  def strip_exif
    if file_ext.downcase == 'jpg' then
      # FIXME: awesome way to strip EXIF.
      #        This will silently fail on systems without jhead in their PATH
      #        and may cause confusion for some bored ones.
      system('jhead', '-purejpg', tempfile_path)
    end
  end
  
  def ensure_tempfile_exists
    unless File.exists?(tempfile_path)
      errors.add :file, "not found, try uploading again"
      return false
    end
  end
  
  def validate_content_type
    unless %w(jpg png gif swf).include?(file_ext.downcase)
      errors.add(:file, "is an invalid content type: " + file_ext.downcase)
      return false
    end
  end
  
  def pretty_file_name(options={})
    # Include the post number and tags.  Don't include too many tags for posts that have too
    # many of them.
    options[:type] ||= :image

    # If the filename is too long, it might fail to save or lose the extension when saving.
    # Cut it down as needed.  Most tags on moe with lots of tags have lots of characters,
    # and those tags are the least important (compared to tags like artists, circles, "fixme",
    # etc).
    #
    # Prioritize tags:
    # - remove artist and circle tags last; these are the most important
    # - general tags can either be important ("fixme") or useless ("red hair")
    # - remove character tags first; 

    tags = Tag.compact_tags(self.cached_tags, 150)
    if options[:type] == :sample then
      tags = "sample"
    end

    # Filter characters.
    tags = tags.gsub(/[\/]/, "_")

    name = "#{self.id} #{tags}"
    if CONFIG["download_filename_prefix"] != ""
      name = CONFIG["download_filename_prefix"] + " " + name
    end

    name
  end

  def file_name
    md5 + "." + file_ext
  end

  def delete_tempfile
    FileUtils.rm_f(tempfile_path)
    FileUtils.rm_f(tempfile_preview_path)
    FileUtils.rm_f(tempfile_sample_path)
    FileUtils.rm_f(tempfile_jpeg_path)
  end

  def tempfile_prefix
    if _tempfile_prefix.blank?
      _tempfile_prefix = Rails.root.join 'public/data'
      if self.id
        _tempfile_prefix.join "temp-id-#{self.id}"
      else
        _tempfile_prefix.join "temp--#{Random.new.rand(2**32)}"
      end
    end
    return _tempfile_prefix
  end

  def tempfile_path
    "#{tempfile_prefix}.upload"
  end

  def tempfile_preview_path
    "#{tempfile_prefix}-preview.jpg"
  end

  def tempfile_sample_path
    "#{tempfile_prefix}-sample.jpg"
  end

  def tempfile_jpeg_path
    "#{tempfile_prefix}-jpeg.jpg"
  end

  # Generate MD5 and CRC32 hashes for the file.  Do this before generating samples, so if this
  # is a duplicate we'll notice before we spend time resizing the image.
  def regenerate_hash
    path = tempfile_path
    if not File.exists?(path)
      path = file_path
    end

    if not File.exists?(path)
      errors.add(:file, "not found")
      return false
    end

    # Compute both hashes in one pass.
    md5_obj = Digest::MD5.new
    crc32_accum = 0
    File.open(path, 'rb') { |fp|
      buf = ""
      while fp.read(1024*64, buf) do
        md5_obj << buf
        crc32_accum = Zlib.crc32(buf, crc32_accum)
      end
    }

    self.md5 = md5_obj.hexdigest
    self.crc32 = crc32_accum
  end

  def regenerate_jpeg_hash
    return false if not has_jpeg?

    crc32_accum = 0
    File.open(jpeg_path, 'rb') { |fp|
      buf = ""
      while fp.read(1024*64, buf) do
        crc32_accum = Zlib.crc32(buf, crc32_accum)
      end
    }
    return false if self.jpeg_crc32 == crc32_accum

    self.jpeg_crc32 = crc32_accum
    return true
  end

  def generate_hash
    if not regenerate_hash
      return false
    end

    if Post.exists?(["md5 = ?", md5])
      delete_tempfile
      errors.add "md5", "already exists"
      return false
    else
      return true
    end
  end

  # Generate the specified image type.  If options[:force_regen] is set, generate the file even
  # if it already exists.
  def regenerate_images(type, options = {})
    return true unless image?

    if type == :sample then
      return false if not generate_sample(options[:force_regen])
      temp_path = tempfile_sample_path
      dest_path = sample_path
    elsif type == :jpeg then
      return false if not generate_jpeg(options[:force_regen])
      temp_path = tempfile_jpeg_path
      dest_path = jpeg_path
    elsif type == :preview then
      return false if not generate_preview
      temp_path = tempfile_preview_path
      dest_path = preview_path
    else
      raise Exception, "unknown type: %s" % type
    end

    # Only move in the changed files on success.  When we return false, the caller won't
    # save us to the database; we need to only move the new files in if we're going to be
    # saved.  This is normally handled by move_file.
    if File.exists?(temp_path)
      FileUtils.mkdir_p(File.dirname(dest_path), :mode => 0775)
      FileUtils.mv(temp_path, dest_path)
      FileUtils.chmod(0775, dest_path)
    end

    return true
  end

  def generate_preview
    return true unless image? && width && height

    size = Danbooru.reduce_to({:width=>width, :height=>height}, {:width=>300, :height=>300})

    # Generate the preview from the new sample if we have one to save CPU, otherwise from the image.
    if File.exists?(tempfile_sample_path)
      path, ext = tempfile_sample_path, "jpg"
    elsif File.exists?(sample_path)
      path, ext = sample_path, "jpg"
    elsif File.exists?(tempfile_path)
      path, ext = tempfile_path, file_ext
    elsif File.exists?(file_path)
      path, ext = file_path, file_ext
    else
      errors.add(:file, "not found")
      return false
    end

    begin
      Danbooru.resize(ext, path, tempfile_preview_path, size, 85)
    rescue Exception => x
      errors.add "preview", "couldn't be generated (#{x})"
      return false
    end

    return true
  end

  # Automatically download from the source if it's a URL.
  attr_accessor :received_file
  def download_source
    return if source !~ /^http:\/\// || !file_ext.blank?
    return if received_file
    
    begin
      Danbooru.http_get_streaming(source) do |response|
        File.open(tempfile_path, "wb") do |out|
          response.read_body do |block|
            out.write(block)
          end
        end
      end

      if self.source.to_s =~ /^http/ and self.source.to_s !~ /pixiv\.net/ then
        #self.source = "Image board"
        self.source = ""
      end

      return true
    rescue SocketError, URI::Error, Timeout::Error, SystemCallError => x
      delete_tempfile
      errors.add "source", "couldn't be opened: #{x}"
      return false
    end
  end
  
  def determine_content_type
    if not File.exists?(tempfile_path)
      errors.add_to_base("No file received")
      return false
    end

    imgsize = ImageSize.new(File.open(tempfile_path, "rb"))

    unless imgsize.get_width.nil?
      self.file_ext = imgsize.get_type.gsub(/JPEG/, "JPG").downcase
    end
  end

  # Assigns a CGI file to the post. This writes the file to disk and generates a unique file name.
  def file=(f)
    return if f.nil? || f.size == 0

    if f.tempfile.path
      # Large files are stored in the temp directory, so instead of
      # reading/rewriting through Ruby, just rely on system calls to
      # copy the file to danbooru's directory.
      FileUtils.cp(f.tempfile.path, tempfile_path)
    else
      File.open(tempfile_path, 'wb') {|nf| nf.write(f.read)}
    end

    self.received_file = true
  end

  def set_image_dimensions
    if image? or flash?
      imgsize = ImageSize.new(File.open(tempfile_path, "rb"))
      self.width = imgsize.get_width
      self.height = imgsize.get_height
    end
    self.file_size = File.size(tempfile_path) rescue 0
  end

  # If the image resolution is too low and the user is privileged or below, force the
  # image to pending.  If the user has too many pending posts, raise an error.
  #
  # We have to do this here, so on creation it's done after set_image_dimensions so
  # we know the size.  If we do it in another module the order of operations is unclear.
  def image_is_too_small
    return false if CONFIG["min_mpixels"].nil?
    return false if self.width.nil?
    return false if self.width * self.height >= CONFIG["min_mpixels"]
    return true
  end

  def set_image_status
    return true if not image_is_too_small

    return if self.user.is_contributor_or_higher?

    self.status = "pending"
    self.status_reason = "low-res"
    return true
  end

  # If this post is pending, and the user has too many pending posts, reject the upload.
  # This must be done after set_image_status.
  def check_pending_count
    return if CONFIG["max_pending_images"].nil?
    return if self.status != "pending"
    return if self.user.is_contributor_or_higher?

    pending_posts = Post.count(:conditions => ["user_id = ? AND status = 'pending'", self.user_id])
    return if pending_posts < CONFIG["max_pending_images"]

    errors.add_to_base("You have too many posts pending moderation")
    return false
  end

  # Returns true if the post is an image format that GD can handle.
  def image?
    %w(jpg jpeg gif png).include?(file_ext.downcase)
  end

  # Returns true if the post is a Flash movie.
  def flash?
    file_ext == "swf"
  end

  def find_ext(file_path)
    ext = File.extname(file_path)
    if ext.blank?
      return "txt"
    else
      ext = ext[1..-1].downcase
      ext = "jpg" if ext == "jpeg"
      return ext
    end
  end

  def content_type_to_file_ext(content_type)
    case content_type.chomp
    when "image/jpeg"
      return "jpg"

    when "image/gif"
      return "gif"

    when "image/png"
      return "png"

    when "application/x-shockwave-flash"
      return "swf"

    else
      nil
    end
  end
  
  def raw_preview_dimensions
    if image?
      dim = Danbooru.reduce_to({:width => width, :height => height}, {:width => 300, :height => 300})
      return [dim[:width], dim[:height]]
    else
      return [300, 300]
    end
  end

  def preview_dimensions
    if image?
      dim = Danbooru.reduce_to({:width => width, :height => height}, {:width => 150, :height => 150})
      return [dim[:width], dim[:height]]
    else
      return [150, 150]
    end
  end
  
  def generate_sample(force_regen = false)
    return true unless image?
    return true unless CONFIG["image_samples"]
    return true unless (width && height)
    return true if (file_ext.downcase == "gif")

    # Always create samples for PNGs.
    if file_ext.downcase == "png" then
      ratio = 1
    else
      ratio = CONFIG["sample_ratio"]
    end

    size = {:width => width, :height => height}
    if not CONFIG["sample_width"].nil?
      size = Danbooru.reduce_to(size, {:width => CONFIG["sample_width"], :height => CONFIG["sample_height"]}, ratio)
    end
    size = Danbooru.reduce_to(size, {:width => CONFIG["sample_max"], :height => CONFIG["sample_min"]}, ratio, false, true)

    # We can generate the sample image during upload or offline.  Use tempfile_path
    # if it exists, otherwise use file_path.
    path = tempfile_path
    path = file_path unless File.exists?(path)
    unless File.exists?(path)
      errors.add(:file, "not found")
      return false
    end

    # If we're not reducing the resolution for the sample image, only reencode if the
    # source image is above the reencode threshold.  Anything smaller won't be reduced
    # enough by the reencode to bother, so don't reencode it and save disk space.
    if size[:width] == width && size[:height] == height && File.size?(path) < CONFIG["sample_always_generate_size"]
      self.sample_width = nil
      self.sample_height = nil
      return true
    end

    # If we already have a sample image, and the parameters havn't changed,
    # don't regenerate it.
    if !force_regen && (size[:width] == sample_width && size[:height] == sample_height)
      return true
    end

    begin
      Danbooru.resize(file_ext, path, tempfile_sample_path, size, CONFIG["sample_quality"])
    rescue Exception => x
      errors.add "sample", "couldn't be created: #{x}"
      return false
    end

    self.sample_width = size[:width]
    self.sample_height = size[:height]
    self.sample_size = File.size(tempfile_sample_path)

    crc32_accum = 0
    File.open(tempfile_sample_path, 'rb') { |fp|
      buf = ""
      while fp.read(1024*64, buf) do
        crc32_accum = Zlib.crc32(buf, crc32_accum)
      end
    }
    self.sample_crc32 = crc32_accum

    return true
  end

  # Returns true if the post has a sample image.
  def has_sample?
    sample_width.is_a?(Integer)
  end

  # Returns true if the post has a sample image, and we're going to use it.
  def use_sample?(user = nil)
    if user && !user.show_samples?
      false
    else
      CONFIG["image_samples"] && has_sample?
    end
  end

  def get_file_image(user = nil)
    {
      :url => file_url,
      :ext => file_ext,
      :size => file_size,
      :width => width,
      :height => height
    }
  end
  def get_file_jpeg(user = nil)
    if status == "deleted" or !use_jpeg?(user)
      return get_file_image(user)
    end

    {
      :url => store_jpeg_url,
      :size => jpeg_size,
      :ext => "jpg",
      :width => jpeg_width,
      :height => jpeg_height
    }
  end
  def get_file_sample(user = nil)
    if status == "deleted" or !use_sample?(user)
      return get_file_jpeg(user)
    end

    {
      :url => store_sample_url,
      :size => sample_size,
      :ext => "jpg",
      :width => sample_width,
      :height => sample_height
    }
  end

  def sample_url(user = nil) get_file_sample(user)[:url] end
  def get_sample_width(user = nil) get_file_sample(user)[:width] end
  def get_sample_height(user = nil) get_file_sample(user)[:height] end

  # If the JPEG version needs to be generated (or regenerated), output it to tempfile_jpeg_path.  On
  # error, return false; on success or no-op, return true.
  def generate_jpeg(force_regen = false)
    return true unless image?
    return true unless CONFIG["jpeg_enable"]
    return true unless (width && height)
    # Only generate JPEGs for PNGs.  Don't do it for files that are already JPEGs; we'll just add
    # artifacts and/or make the file bigger.  Don't do it for GIFs; they're usually animated.
    return true if (file_ext.downcase != "png")

    # We can generate the image during upload or offline.  Use tempfile_path
    # if it exists, otherwise use file_path.
    path = tempfile_path
    path = file_path unless File.exists?(path)
    unless File.exists?(path)
      errors.add(:file, "not found")
      return false
    end

    # If we already have the image, don't regenerate it.
    if !force_regen && jpeg_width.is_a?(Integer)
      return true
    end

    size = Danbooru.reduce_to({:width => width, :height => height}, {:width => CONFIG["jpeg_width"], :height => CONFIG["jpeg_height"]}, CONFIG["jpeg_ratio"])
    begin
      Danbooru.resize(file_ext, path, tempfile_jpeg_path, size, CONFIG["jpeg_quality"])
    rescue Exception => x
      errors.add "jpeg", "couldn't be created: #{x}"
      return false
    end

    self.jpeg_width = size[:width]
    self.jpeg_height = size[:height]
    self.jpeg_size = File.size(tempfile_jpeg_path)

    crc32_accum = 0
    File.open(tempfile_jpeg_path, 'rb') { |fp|
      buf = ""
      while fp.read(1024*64, buf) do
        crc32_accum = Zlib.crc32(buf, crc32_accum)
      end
    }
    self.jpeg_crc32 = crc32_accum

    return true
  end

  def has_jpeg?
    jpeg_width.is_a?(Integer)
  end

  # Returns true if the post has a JPEG version, and we're going to use it.
  def use_jpeg?(user = nil)
    CONFIG["jpeg_enable"] && has_jpeg?
  end

  def jpeg_url(user = nil)
    get_file_jpeg(user)[:url]
  end
end
