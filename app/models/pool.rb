require "mirror"
require "erb"
include ERB::Util

class Pool < ApplicationRecord
  belongs_to :user
  validates_presence_of :name

  class PostAlreadyExistsError < Exception
  end

  class AccessDeniedError < Exception
  end

  module PostMethods
    def self.included(m)
      m.has_many :pool_posts, lambda { where("pools_posts.active").order(Arel.sql("nat_sort(sequence), post_id")) }, :class_name => "PoolPost"
      m.has_many :all_pool_posts, lambda { order Arel.sql("nat_sort(sequence), post_id") }, :class_name => "PoolPost"
      m.versioned :name
      m.versioned :description, :default => ""
      m.versioned :is_public, :default => true
      m.versioned :is_active, :default => true
      m.set_callback :undo, :after, :update_pool_links
      m.after_save :expire_cache
    end

    def can_be_updated_by?(user)
      is_public? || user.has_permission?(self)
    end

    def add_post(post_id, options = {})
      transaction do
        if options[:user] && !can_be_updated_by?(options[:user])
          raise AccessDeniedError
        end

        seq = options[:sequence] || next_sequence

        pool_post = all_pool_posts.where(:post_id => post_id).first
        if pool_post
          # If :ignore_already_exists, we won't raise PostAlreadyExistsError; this allows
          # he sequence to be changed if the post already exists.
          raise PostAlreadyExistsError if pool_post.active && !options[:ignore_already_exists]
          pool_post.active = true
          pool_post.sequence = seq
          pool_post.save!
        else
          PoolPost.create(:pool_id => id, :post_id => post_id, :sequence => seq)
        end

        unless options[:skip_update_pool_links]
          reload
          update_pool_links
        end
      end
    end

    def remove_post(post_id, options = {})
      transaction do
        if options[:user] && !can_be_updated_by?(options[:user])
          raise AccessDeniedError
        end

        pool_post = all_pool_posts.where(:post_id => post_id).first
        if pool_post
          pool_post.active = false
          pool_post.save!

          reload # saving pool_post modified us
          update_pool_links
        end
      end
    end

    def recalculate_post_count
      self.post_count = pool_posts.count
    end

    def transfer_post_to_parent(post_id, parent_id)
      pool_post = pool_posts.find_by(:post_id => post_id)
      parent_pool_post = pool_posts.find_by(:post_id => parent_id)
      return unless parent_pool_post.nil?

      sequence = pool_post.sequence
      remove_post(post_id)
      add_post(parent_id, :sequence => sequence)
    end

    def get_sample
      # By preference, pick the first post (by sequence) in the pool that isn't hidden from
      # the index.
      PoolPost.joins(:post)
        .where(:pool_id => id, :active => true, :posts => { :status => "active" })
        .order(Arel.sql("posts.is_shown_in_index DESC, NAT_SORT(pools_posts.sequence), pools_posts.post_id"))
        .to_a
        .find { |pool_post| pool_post if pool_post.post.can_be_seen_by?(Thread.current["danbooru-user"]) }
        .try(:post)
    end

    def can_change_is_public?(user)
      user.has_permission?(self)
    end

    def can_change?(user, _attribute)
      return false unless user.is_member_or_higher?
      is_public? || user.has_permission?(self)
    end

    def update_pool_links
      transaction do
        pp = pool_posts.reload
        pp.each_with_index do |post, i|
          post.next_post_id = (i == pp.size - 1) ? nil : pp[i + 1].post_id
          post.prev_post_id = i == 0 ? nil : pp[i - 1].post_id
          post.save if post.changed?
        end
      end
    end

    def next_sequence
      (pool_posts.pluck(:sequence).map(&:to_i).max || 0) + 1
    end

    def expire_cache
      Moebooru::CacheHelper.increment_version
    end
  end

  module ApiMethods
    def api_attributes
      {
        :id => id,
        :name => name,
        :created_at => created_at,
        :updated_at => updated_at,
        :user_id => user_id,
        :is_public => is_public,
        :post_count => post_count,
        :description => description
      }
    end

    def as_json(*params)
      api_attributes.as_json(*params)
    end

    def to_xml(options = {})
      options[:indent] ||= 2
      xml = options[:builder] ||= Builder::XmlMarkup.new(:indent => options[:indent])
      xml.pool(api_attributes) do
        xml.description(description)
        yield options[:builder] if block_given?
      end
    end
  end

  module NameMethods
    module ClassMethods
      def find_by_name(name)
        if name =~ /^\d+$/
          find_by(:id => name)
        else
          find_by("LOWER(name) = LOWER(?)", name)
        end
      end
    end

    def self.included(m)
      m.extend(ClassMethods)
      m.validates_uniqueness_of :name
      m.before_validation :normalize_name
    end

    def normalize_name
      self.name = name.gsub(/\s/, "_")
    end

    def pretty_name
      name.tr("_", " ")
    end
  end

  module ZipMethods
    def get_zip_filename(options = {})
      filename = pretty_name.gsub(/\?/, "")
      filename += " (JPG)" if options[:jpeg]
      "#{filename}.zip"
    end

    # Return true if any posts in this pool have a generated JPEG version.
    def has_jpeg_zip?(_options = {})
      pool_posts.each do |pool_post|
        post = pool_post.post
        return true if post.has_jpeg?
      end
      false
    end

    # Estimate the size of the ZIP.
    def get_zip_size(options = {})
      sum = 0
      pool_posts.each do |pool_post|
        post = pool_post.post
        next if post.status == "deleted"
        sum += options[:jpeg] && post.has_jpeg? ? post.jpeg_size : post.file_size
      end

      sum
    end

    # nginx version
    def get_zip_data(options = {})
      return "" if pool_posts.empty?

      jpeg = options[:jpeg] || false

      buf = []

      # Pad sequence numbers in filenames to the longest sequence number.  Ignore any text
      # after the sequence for padding; for example, if we have 1, 5, 10a and 12, then pad
      # to 2 digits.

      # Always pad to at least 3 digits.
      max_sequence_digits = 3
      pool_posts.each do |pool_post|
        filtered_sequence = pool_post.sequence.gsub(/^([0-9]+(-[0-9]+)?)?.*/, '\1') # 45a -> 45
        filtered_sequence.split(/-/).each do |p|
          max_sequence_digits = [p.length, max_sequence_digits].max
        end
      end

      filename_count = {}
      pool_posts.each do |pool_post|
        post = pool_post.post
        next if post.status == "deleted"

        # Strip Rails.root/public off the file path, so the paths are relative to document-root.
        if jpeg && post.has_jpeg?
          path = post.jpeg_path
          file_ext = "jpg"
        else
          path = post.file_path
          file_ext = post.file_ext
        end
        path = path[Rails.root.join("public").to_s.length..path.length]

        # For padding filenames, break numbers apart on hyphens and pad each part.  For
        # example, if max_sequence_digits is 3, and we have "88-89", pad it to "088-089".
        filename = pool_post.sequence.gsub(/^([0-9]+(-[0-9]+)*)(.*)$/) do |_m|
          if Regexp.last_match[1] != ""
            suffix = Regexp.last_match[3]
            numbers = Regexp.last_match[1].split(/-/).map do |p|
              "%0*i" % [max_sequence_digits, p.to_i]
            end.join("-")
            "%s%s" % [numbers, suffix]
          else
            "%s" % [Regexp.last_match[3]]
          end
        end

        # filename = "%0*i" % [max_sequence_digits, pool_post.sequence]

        # Avoid duplicate filenames.
        filename_count[filename] ||= 0
        filename_count[filename] = filename_count[filename] + 1
        if filename_count[filename] > 1
          filename << " (%i)" % [filename_count[filename]]
        end
        filename << ".%s" % [file_ext]

        # buf << "#{filename}\n"
        # buf << "#{path}\n"
        if jpeg && post.has_jpeg?
          file_size = post.jpeg_size
          crc32 = post.jpeg_crc32
        else
          file_size = post.file_size
          crc32 = post.crc32
        end
        crc32 = crc32 ? "%08x" % crc32.to_i : "-"
        buf += [{ :filename => filename, :path => path, :file_size => file_size, :crc32 => crc32 }]
      end

      buf
    end

    # Generate a mod_zipfile control file for this pool.
    def get_zip_control_file(options = {})
      return "" if pool_posts.empty?

      jpeg = options[:jpeg] || false

      buf = ""

      # Pad sequence numbers in filenames to the longest sequence number.  Ignore any text
      # after the sequence for padding; for example, if we have 1, 5, 10a and 12, then pad
      # to 2 digits.

      # Always pad to at least 3 digits.
      max_sequence_digits = 3
      pool_posts.each do |pool_post|
        filtered_sequence = pool_post.sequence.gsub(/^([0-9]+(-[0-9]+)?)?.*/, '\1') # 45a -> 45
        filtered_sequence.split(/-/).each do |p|
          max_sequence_digits = [p.length, max_sequence_digits].max
        end
      end

      filename_count = {}
      pool_posts.each do |pool_post|
        post = pool_post.post
        next if post.status == "deleted"

        # Strip Rails.root/public off the file path, so the paths are relative to document-root.
        if jpeg && post.has_jpeg?
          path = post.jpeg_path
          file_ext = "jpg"
        else
          path = post.file_path
          file_ext = post.file_ext
        end
        path = path[Rails.root.join("public").to_s.length..path.length]

        # For padding filenames, break numbers apart on hyphens and pad each part.  For
        # example, if max_sequence_digits is 3, and we have "88-89", pad it to "088-089".
        filename = pool_post.sequence.gsub(/^([0-9]+(-[0-9]+)*)(.*)$/) do |_m|
          if Regexp.last_match[1] != ""
            suffix = Regexp.last_match[3]
            numbers = Regexp.last_match[1].split(/-/).map do |p|
              "%0*i" % [max_sequence_digits, p.to_i]
            end.join("-")
            "%s%s" % [numbers, suffix]
          else
            "%s" % [Regexp.last_match[3]]
          end
        end

        # filename = "%0*i" % [max_sequence_digits, pool_post.sequence]

        # Avoid duplicate filenames.
        filename_count[filename] ||= 0
        filename_count[filename] = filename_count[filename] + 1
        if filename_count[filename] > 1
          filename << " (%i)" % [filename_count[filename]]
        end
        filename << ".%s" % [file_ext]

        buf << "#{filename}\n"
        buf << "#{path}\n"
        if jpeg && post.has_jpeg?
          buf << "#{post.jpeg_size}\n"
          buf << "#{post.jpeg_crc32}\n"
        else
          buf << "#{post.file_size}\n"
          buf << "#{post.crc32}\n"
        end
      end

      buf
    end
  end

  include PostMethods
  include ApiMethods
  include NameMethods
  if CONFIG["pool_zips"]
    include ZipMethods
  end
end
