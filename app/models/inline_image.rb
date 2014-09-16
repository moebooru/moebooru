require "fileutils"

# InlineImages can be uploaded, copied directly from posts, or cropped from other InlineImages.
# To create an image by cropping a post, the post must be copied to an InlineImage of its own,
# and cropped from there; the only UI for cropping is InlineImage->InlineImage.
#
# InlineImages can be posted directly in the forum and wiki (and possibly comments).
#
# An inline image can have three versions, like a post.  For consistency, they use the
# same names: image, sample, preview.  As with posts, sample and previews are always JPEG,
# and the dimensions of preview is derived from image rather than stored.
#
# Image files are effectively garbage collected: InlineImages can share files, and the file
# is deleted when the last one using it is deleted.  This allows any user to copy another user's
# InlineImage, to crop it or to include it in an Inline.
#
# Example use cases:
#
# - Plain inlining, eg. for tutorials.  Thumbs and larger images can be shown inline, allowing
# a click to expand.
# - Showing edits.  Each user can upload his edit as an InlineImage and post it directly
# into the forum.
# - Comparing edits.  A user can upload his own edit, pair it with another version (using
# Inline), crop to a region of interest, and post that inline.  The images can then be
# compared in-place.  This can be used to clearly show editing problems and differences.

class InlineImage < ActiveRecord::Base
  belongs_to :inline
  before_validation :download_source, :on => :create
  before_validation :determine_content_type, :on => :create
  before_validation :set_image_dimensions, :on => :create
  before_validation :generate_sample, :on => :create
  before_validation :generate_preview, :on => :create
  before_validation :move_file, :on => :create
  before_validation :set_default_sequence, :on => :create
  after_destroy :delete_file
  before_create :validate_uniqueness
  include Moebooru::TempfilePrefix

  def tempfile_image_path
    "#{tempfile_prefix}.upload"
  end

  def tempfile_sample_path
    "#{tempfile_prefix}-sample.upload"
  end

  def tempfile_preview_path
    "#{tempfile_prefix}-preview.upload"
  end

  attr_accessor :source
  attr_accessor :received_file
  attr_accessor :file_needs_move
  def post_id=(id)
    post = Post.find_by_id(id)
    file = post.file_path

    FileUtils.ln_s(file, tempfile_image_path)

    self.received_file = true
    self.md5 = post.md5
  end

  # Call once a file is available in tempfile_image_path.
  def got_file
    generate_hash(tempfile_image_path)
    FileUtils.chmod(0775, tempfile_image_path)
    self.file_needs_move = true
    self.received_file = true
  end

  def file=(f)
    return if f.nil? || f.size == 0

    if f.tempfile.path
      FileUtils.cp(f.tempfile.path, tempfile_image_path)
    else
      File.open(tempfile_image_path, "wb") { |nf| nf.write(f.read) }
    end

    got_file
  end

  def download_source
    return if source !~ /^http:\/\// || !file_ext.blank?
    return if received_file

    begin
      Danbooru.http_get_streaming(source) do |response|
        File.open(tempfile_image_path, "wb") do |out|
          response.read_body do |block|
            out.write(block)
          end
        end
      end
      got_file

      return true
    rescue SocketError, URI::Error, Timeout::Error, SystemCallError => x
      delete_tempfile
      errors.add "source", "couldn't be opened: #{x}"
      return false
    end
  end

  def determine_content_type
    return true if file_ext

    unless File.exist?(tempfile_image_path)
      errors.add(:base, "No file received")
      return false
    end

    imgsize = ImageSize.path(tempfile_image_path)

    unless imgsize.format.nil?
      self.file_ext = imgsize.format.to_s.gsub(/jpeg/i, "jpg").downcase
    end

    unless %w(jpg png gif).include?(file_ext.downcase)
      errors.add(:file, "is an invalid content type: " + (file_ext.downcase || "unknown"))
      return false
    end

    true
  end

  def set_image_dimensions
    return true if width && height
    imgsize = ImageSize.path(tempfile_image_path)
    self.width = imgsize.width
    self.height = imgsize.height

    true
  end

  def preview_dimensions
    Moebooru::Resizer.reduce_to({ :width => width, :height => height }, { :width => 150, :height => 150 })
  end

  def thumb_size
    Moebooru::Resizer.reduce_to({ :width => width, :height => height }, { :width => 400, :height => 400 })
  end

  def generate_sample
    return true if File.exist?(sample_path)

    # We can generate the sample image during upload or offline.  Use tempfile_image_path
    # if it exists, otherwise use file_path.
    path = tempfile_image_path
    path = file_path unless File.exist?(path)
    unless File.exist?(path)
      errors.add(:file, "not found")
      return false
    end

    # If we're not reducing the resolution for the sample image, only reencode if the
    # source image is above the reencode threshold.  Anything smaller won't be reduced
    # enough by the reencode to bother, so don't reencode it and save disk space.
    sample_size = Moebooru::Resizer.reduce_to({ :width => width, :height => height }, { :width => CONFIG["inline_sample_width"], :height => CONFIG["inline_sample_height"] })
    if sample_size[:width] == width && sample_size[:height] == height && File.size?(path) < CONFIG["sample_always_generate_size"]
      return true
    end

    # If we already have a sample image, and the parameters havn't changed,
    # don't regenerate it.
    if sample_size[:width] == sample_width && sample_size[:height] == sample_height
      return true
    end

    begin
      Moebooru::Resizer.resize(file_ext, path, tempfile_sample_path, sample_size, 95)
    rescue => x
      errors.add "sample", "couldn't be created: #{x}"
      return false
    end

    self.sample_width = sample_size[:width]
    self.sample_height = sample_size[:height]
    true
  end

  def generate_preview
    return true if File.exist?(preview_path)

    unless File.exist?(tempfile_image_path)
      errors.add(:file, "not found")
      return false
    end

    # Generate the preview from the new sample if we have one to save CPU, otherwise from the image.
    if File.exist?(tempfile_sample_path)
      path, ext = tempfile_sample_path, "jpg"
    else
      path, ext = tempfile_image_path, file_ext
    end

    begin
      Moebooru::Resizer.resize(ext, path, tempfile_preview_path, preview_dimensions, 95)
    rescue => x
      errors.add "preview", "couldn't be generated (#{x})"
      return false
    end
    true
  end

  def move_file
    return true unless file_needs_move
    FileUtils.mkdir_p(File.dirname(file_path))
    FileUtils.mv(tempfile_image_path, file_path)

    if File.exist?(tempfile_preview_path)
      FileUtils.mkdir_p(File.dirname(preview_path))
      FileUtils.mv(tempfile_preview_path, preview_path)
    end
    if File.exist?(tempfile_sample_path)
      FileUtils.mkdir_p(File.dirname(sample_path))
      FileUtils.mv(tempfile_sample_path, sample_path)
    end
    self.file_needs_move = false
    true
  end

  def set_default_sequence
    return unless sequence.nil?
    siblings = inline.inline_images
    max_sequence = siblings.map(&:sequence).max
    max_sequence ||= 0
    self.sequence = max_sequence + 1
  end

  def generate_hash(path)
    md5_obj = Digest::MD5.new
    File.open(path, "rb") do |fp|
      buf = ""
      while fp.read(1024 * 64, buf) do md5_obj << buf end
    end

    self.md5 = md5_obj.hexdigest
  end

  def has_sample?
    (!sample_height.nil?)
  end

  def file_name
    "#{md5}.#{file_ext}"
  end

  def file_name_jpg
    "#{md5}.jpg"
  end

  def file_path
    "#{Rails.root}/public/data/inline/image/#{file_name}"
  end

  def preview_path
    "#{Rails.root}/public/data/inline/preview/#{file_name_jpg}"
  end

  def sample_path
    "#{Rails.root}/public/data/inline/sample/#{file_name_jpg}"
  end

  def file_url
    CONFIG["url_base"] + "/data/inline/image/#{file_name}"
  end

  def sample_url
    if self.has_sample?
      return CONFIG["url_base"] + "/data/inline/sample/#{file_name_jpg}"
    else
      return file_url
    end
  end

  def preview_url
    CONFIG["url_base"] + "/data/inline/preview/#{file_name_jpg}"
  end

  def delete_file
    # If several inlines use the same image, they'll share the same file via the MD5.  Only
    # delete the file if this is the last one using it.
    exists = InlineImage.find(:first, :conditions => ["id <> ? AND md5 = ?", id, md5])
    return unless exists.nil?

    FileUtils.rm_f(file_path)
    FileUtils.rm_f(preview_path)
    FileUtils.rm_f(sample_path)
  end

  # We should be able to use validates_uniqueness_of for this, but Rails is completely
  # brain-damaged: it only lets you specify an error message that starts with the name
  # of the column, capitalized, so if we say "foo", the message is "Md5 foo".  This is
  # useless.
  def validate_uniqueness
    siblings = inline.inline_images
    for s in siblings do
      next if s.id == self
      if s.md5 == md5
        errors.add(:base, "##{s.sequence} already exists.")
        return false
      end
    end
    true
  end

  def api_attributes
    {
      :id => id,
      :sequence => sequence,
      :md5 => md5,
      :width => width,
      :height => height,
      :sample_width => sample_width,
      :sample_height => sample_height,
      :preview_width => preview_dimensions[:width],
      :preview_height => preview_dimensions[:height],
      :description => description,
      :file_url => file_url,
      :sample_url => sample_url,
      :preview_url => preview_url
    }
  end

  def as_json(*params)
    api_attributes.as_json(*params)
  end
end
