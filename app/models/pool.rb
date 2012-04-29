require 'mirror'
require "erb"
include ERB::Util

class Pool < ActiveRecord::Base  
  belongs_to :user
  
  class PostAlreadyExistsError < Exception
  end
  
  class AccessDeniedError < Exception
  end
  
  module PostMethods
    def self.included(m)
      m.extend(ClassMethods)
      m.has_many :pool_posts, :class_name => "PoolPost", :order => "nat_sort(sequence), post_id", :conditions => "pools_posts.active"
      m.has_many :all_pool_posts, :class_name => "PoolPost", :order => "nat_sort(sequence), post_id"
      m.versioned :name
      m.versioned :description, :default => ""
      m.versioned :is_public, :default => true
      m.versioned :is_active, :default => true
      m.after_undo :update_pool_links
      m.after_save :expire_cache
    end
    
    module ClassMethods
      def get_pool_posts_from_posts(posts)
        post_ids = posts.map { |post| post.id }
        return [] if post_ids.empty?

        sql = "SELECT pp.* FROM pools_posts pp WHERE pp.active AND pp.post_id IN (%s)" % post_ids.join(",")
        return PoolPost.find_by_sql(sql)
      end

      def get_pools_from_pool_posts(pool_posts)
        pool_ids = pool_posts.map { |pp| pp.pool_id }.uniq
        return [] if pool_ids.empty?

        sql = "SELECT p.* FROM pools p WHERE p.id IN (%s)" % pool_ids.join(",")
        return Pool.find_by_sql(sql)
      end
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

        pool_post = all_pool_posts.find(:first, :conditions => ["post_id = ?", post_id])
        if pool_post
          # If :ignore_already_exists, we won't raise PostAlreadyExistsError; this allows
          # he sequence to be changed if the post already exists.
          raise PostAlreadyExistsError if pool_post.active and not options[:ignore_already_exists]
          pool_post.active = true
          pool_post.sequence = seq
          pool_post.save!
        else
          PoolPost.create(:pool_id => id, :post_id => post_id, :sequence => seq)
        end
        
        unless options[:skip_update_pool_links]
          self.reload
          update_pool_links
        end
      end
    end

    def remove_post(post_id, options = {})
      transaction do
        if options[:user] && !can_be_updated_by?(options[:user])
          raise AccessDeniedError
        end
        
        pool_post = all_pool_posts.find(:first, :conditions => ["post_id = ?", post_id])
        if pool_post then
          pool_post.active = false
          pool_post.save!

          self.reload # saving pool_post modified us
          update_pool_links
        end
      end
    end

    def recalculate_post_count
      self.post_count = pool_posts.count
    end

    def transfer_post_to_parent(post_id, parent_id)
      pool_post = pool_posts.find(:first, :conditions => ["post_id = ?", post_id])
      parent_pool_post = pool_posts.find(:first, :conditions => ["post_id = ?", parent_id])
      return if not parent_pool_post.nil?

      sequence = pool_post.sequence
      self.remove_post(post_id)
      self.add_post(parent_id, :sequence => sequence)
    end
    
    def get_sample
      # By preference, pick the first post (by sequence) in the pool that isn't hidden from
      # the index.
      PoolPost.find(:all, :order => "posts.is_shown_in_index DESC, nat_sort(pools_posts.sequence), pools_posts.post_id",
                    :joins => "JOIN posts ON posts.id = pools_posts.post_id",
                    :conditions => ["pool_id = ? AND posts.status = 'active' AND pools_posts.active", self.id]).each { |pool_post|
        return pool_post.post if pool_post.post.can_be_seen_by?(Thread.current["danbooru-user"])
      }
      return rescue nil
    end

    def can_change_is_public?(user)
      user.has_permission?(self)
    end

    def can_change?(user, attribute)
      return false if not user.is_member_or_higher?
      return is_public? || user.has_permission?(self)
    end

    def update_pool_links
      transaction do
        pp = pool_posts(true) # force reload
        pp.each_index do |i|
          pp[i].next_post_id = (i == pp.size - 1) ? nil : pp[i + 1].post_id
          pp[i].prev_post_id = i == 0 ? nil : pp[i - 1].post_id
          pp[i].save if pp[i].changed?
        end
      end
    end

    def next_sequence
      seq = 0
      pool_posts.find(:all, :select => "sequence", :order => "sequence DESC").each { |pp|
        seq = [seq, pp.sequence.to_i].max
      }
      
      return seq + 1
    end

    def expire_cache
      Cache.expire
    end
  end
  
  module ApiMethods
    def api_attributes
      return {
        :id => id,
        :name => name,
        :created_at => created_at,
        :updated_at => updated_at,
        :user_id => user_id,
        :is_public => is_public,
        :post_count => post_count,
        :description => description,
      }
    end
    
    def to_json(*params)
      api_attributes.to_json(*params)
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
          find_by_id(name)
        else
          find(:first, :conditions => ["lower(name) = lower(?)", name])
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
    def get_zip_filename(options={})
      filename = pretty_name.gsub(/\?/, "")
      filename += " (JPG)" if options[:jpeg]
      "#{filename}.zip"
    end

    # Return true if any posts in this pool have a generated JPEG version.
    def has_jpeg_zip?(options={})
      pool_posts.each do |pool_post|
        post = pool_post.post
        return true if post.has_jpeg?
      end
      return false
    end

    def get_zip_url(control_path, options={})
      url = Mirrors.select_image_server(self.zip_is_warehoused, self.zip_created_at.to_i, :zipfile => true)
      url += "/data/zips/#{File.basename(control_path)}"

      # Adds the pretty filename to the end.  This is ignored by lighttpd.
      url += "/#{url_encode(get_zip_filename(options))}"
      return url
    end

    # Estimate the size of the ZIP.
    def get_zip_size(options={})
      sum = 0
      pool_posts.each do |pool_post|
        post = pool_post.post
        next if post.status == 'deleted'
        sum += options[:jpeg] && post.has_jpeg? ? post.jpeg_size : post.file_size
      end

      return sum
    end

    def get_zip_control_file_path_for_time(time, options={})
      jpeg = options[:jpeg] || false

      # If this pool has a JPEG version, name the normal version "png".  Otherwise, name it
      # "normal".  This only affects the URL used to access the file, so the frontend can
      # match it for QOS purposes; it doesn't affect the downloaded pool's filename.
      if jpeg
        type = "jpeg"
      elsif has_jpeg_zip?(options) then
        type = "png"
      else
        type = "normal"
      end

      "#{Rails.root}/public/data/zips/%s-pool-%08i-%i" % [type, self.id, time.to_i]
    end

    def all_posts_in_zip_are_warehoused?(options={})
      pool_posts.each do |pool_post|
        post = pool_post.post
        next if post.status == 'deleted'
        return false if not post.is_warehoused?
      end
      return true
    end
    
    #nginx version
    def get_zip_data(options={})
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
        filtered_sequence.split(/-/).each { |p|
          max_sequence_digits = [p.length, max_sequence_digits].max
        }
      end

      filename_count = {}
      pool_posts.each do |pool_post|
        post = pool_post.post
        next if post.status == 'deleted'

        # Strip RAILS_ROOT/public off the file path, so the paths are relative to document-root.
        if jpeg && post.has_jpeg?
          path = post.jpeg_path
          file_ext = "jpg"
        else
          path = post.file_path
          file_ext = post.file_ext
        end
        path = path[(RAILS_ROOT + "/public").length .. path.length]

        # For padding filenames, break numbers apart on hyphens and pad each part.  For
        # example, if max_sequence_digits is 3, and we have "88-89", pad it to "088-089".
        filename = pool_post.sequence.gsub(/^([0-9]+(-[0-9]+)*)(.*)$/) { |m|
          if $1 != ""
            suffix = $3
            numbers = $1.split(/-/).map { |p|
              "%0*i" % [max_sequence_digits, p.to_i]
            }.join("-")
            "%s%s" % [numbers, suffix]
          else
            "%s" % [$3]
          end
        }

        #filename = "%0*i" % [max_sequence_digits, pool_post.sequence]

        # Avoid duplicate filenames.
        filename_count[filename] ||= 0
        filename_count[filename] = filename_count[filename] + 1
        if filename_count[filename] > 1
          filename << " (%i)" % [filename_count[filename]]
        end
        filename << ".%s" % [file_ext]

        #buf << "#{filename}\n"
        #buf << "#{path}\n"
        if jpeg && post.has_jpeg?
          file_size = post.jpeg_size
          crc32 = post.jpeg_crc32
        else
          file_size = post.file_size
          crc32 = post.crc32
        end
        crc32 = "%x" % crc32
        buf += [{ :filename => filename, :path => path, :file_size => file_size, :crc32 => crc32 }]
      end

      return buf
    end

    # Generate a mod_zipfile control file for this pool.
    def get_zip_control_file(options={})
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
        filtered_sequence.split(/-/).each { |p|
          max_sequence_digits = [p.length, max_sequence_digits].max
        }
      end

      filename_count = {}
      pool_posts.each do |pool_post|
        post = pool_post.post
        next if post.status == 'deleted'

        # Strip RAILS_ROOT/public off the file path, so the paths are relative to document-root.
	if jpeg && post.has_jpeg?
          path = post.jpeg_path
          file_ext = "jpg"
        else
          path = post.file_path
          file_ext = post.file_ext
        end
        path = path[(RAILS_ROOT + "/public").length .. path.length]

	# For padding filenames, break numbers apart on hyphens and pad each part.  For
	# example, if max_sequence_digits is 3, and we have "88-89", pad it to "088-089".
        filename = pool_post.sequence.gsub(/^([0-9]+(-[0-9]+)*)(.*)$/) { |m|
          if $1 != ""
            suffix = $3
            numbers = $1.split(/-/).map { |p|
              "%0*i" % [max_sequence_digits, p.to_i]
            }.join("-")
            "%s%s" % [numbers, suffix]
          else
            "%s" % [$3]
          end
        }

        #filename = "%0*i" % [max_sequence_digits, pool_post.sequence]

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

      return buf
    end

    def get_zip_control_file_path(options = {})
      control_file = self.get_zip_control_file(options)

      # The latest pool ZIP we generated is stored in pool.zip_created_at.  If that ZIP
      # control file still exists, compare it against the control file we just generated,
      # and reuse it if it hasn't changed.
      control_path_time = Time.now
      control_path = self.get_zip_control_file_path_for_time(control_path_time, options)
      reuse_old_control_file = false
      if self.zip_created_at then
        old_path = self.get_zip_control_file_path_for_time(self.zip_created_at, options)
        begin
          old_control_file = File.open(old_path).read

          if control_file == old_control_file
            reuse_old_control_file = true
            control_path = old_path
            control_path_time = self.zip_created_at
          end
        rescue SystemCallError => e
        end
      end

      if not reuse_old_control_file then
        control_path_temp = control_path + ".temp"
        File.open(control_path_temp, 'w+') do |fp|
          fp.write(control_file)
        end

        FileUtils.mv(control_path_temp, control_path)

        # Only after we've attempted to mirror the control file, update self.zip_created_at.
        self.update_attributes(:zip_created_at => control_path_time, :zip_is_warehoused => false)
      end

      if !self.zip_is_warehoused && all_posts_in_zip_are_warehoused?(options)
	delay = ServerKey.find(:first, :conditions => ["name = 'delay-mirrors-down'"])
	if delay.nil?
	  delay = ServerKey.create(:name => "delay-mirrors-down", :value => 0)
	end
	if delay.value.to_i < Time.now.to_i
	  # Send the control file to all mirrors, if we have any.
	  begin
	    # This is being done interactively, so use a low timeout.
	    Mirrors.copy_file_to_mirrors(control_path, :timeout => 5)
	    self.update_attributes(:zip_is_warehoused => true)
          rescue Mirrors::MirrorError => e
	    # If mirroring is failing, disable it for a while.  It might be timing out, and this
	    # will make the UI unresponsive.
	    delay.update_attributes!(:value => Time.now.to_i + 60*60)
	    ActiveRecord::Base.logger.error("Error warehousing ZIP control file: #{e}")
	  end
	end
      end

      return control_path
    end
  end

  include PostMethods
  include ApiMethods
  include NameMethods
  if CONFIG["pool_zips"]
    include ZipMethods
  end
end

