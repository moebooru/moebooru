require 'digest/sha1'

class User < ActiveRecord::Base
  class AlreadyFavoritedError < Exception; end

  module UserBlacklistMethods
    # TODO: I don't see the advantage of normalizing these. Since commas are illegal
    # characters in tags, they can be used to separate lines (with whitespace separating
    # tags). Denormalizing this into a field in users would save a SQL query.
    def self.included(m)
      m.after_save :commit_blacklists
      m.after_create :set_default_blacklisted_tags
      m.has_many :user_blacklisted_tags, :dependent => :delete_all, :order => :id
    end

    def blacklisted_tags=(blacklists)
      @blacklisted_tags = blacklists
    end

    def blacklisted_tags
      blacklisted_tags_array.join("\n") + "\n"
    end

    def blacklisted_tags_array
      user_blacklisted_tags.map {|x| x.tags}
    end

    def commit_blacklists
      if @blacklisted_tags
        user_blacklisted_tags.clear

        @blacklisted_tags.scan(/[^\r\n]+/).each do |tags|
          user_blacklisted_tags.create(:tags => tags)
        end
      end
    end

    def set_default_blacklisted_tags
      CONFIG["default_blacklists"].each do |b|
        UserBlacklistedTag.create(:user_id => self.id, :tags => b)
      end
    end
  end

  module UserAuthenticationMethods
    module ClassMethods
      def authenticate(name, pass)
        authenticate_hash(name, sha1(pass))
      end

      def authenticate_hash(name, pass)
        find(:first, :conditions => ["lower(name) = lower(?) AND password_hash = ?", name, pass])
      end

      def sha1(pass)
        Digest::SHA1.hexdigest("#{salt}--#{pass}--")
      end
    end

    def self.included(m)
      m.extend(ClassMethods)
    end
  end

  module UserPasswordMethods
    attr_accessor :password

    def self.included(m)
      m.before_save :encrypt_password
      m.validates_length_of :password, :minimum => 5, :if => lambda {|rec| rec.password}
      m.validates_confirmation_of :password
    end

    def encrypt_password
      self.password_hash = User.sha1(password) if password
    end

    def reset_password
      consonants = "bcdfghjklmnpqrstvqxyz"
      vowels = "aeiou"
      pass = ""

      4.times do
        pass << consonants[rand(21), 1]
        pass << vowels[rand(5), 1]
      end

      pass << rand(100).to_s
      execute_sql("UPDATE users SET password_hash = ? WHERE id = ?", User.sha1(pass), self.id)
      return pass
    end
  end

  module UserCountMethods
    module ClassMethods
      # TODO: This isn't used anymore. Should be safe to delete.
      def fast_count
        return select_value_sql("SELECT row_count FROM table_data WHERE name = 'users'").to_i
      end
    end

    def self.included(m)
      m.extend(ClassMethods)
      m.after_create :increment_count
      m.after_destroy :decrement_count
    end

    def increment_count
      connection.execute("update table_data set row_count = row_count + 1 where name = 'users'")
    end

    def decrement_count
      connection.execute("update table_data set row_count = row_count - 1 where name = 'users'")
    end
  end

  module UserNameMethods
    module ClassMethods
      def find_name_helper(user_id)
        if user_id.nil?
          return CONFIG["default_guest_name"]
        end

        user = find(:first, :conditions => ["id = ?", user_id], :select => "name")

        if user
          return user.name
        else
          return CONFIG["default_guest_name"]
        end
      end

      def find_name(user_id)
        if CONFIG["enable_caching"]
          return Rails.cache.fetch("user_name:#{user_id}") do
            find_name_helper(user_id)
          end
        else
          find_name_helper(user_id)
        end
      end

      def find_by_name(name)
        find(:first, :conditions => ["lower(name) = lower(?)", name])
      end
    end

    def self.included(m)
      m.extend(ClassMethods)
      m.validates_length_of :name, :within => 2..20, :on => :create
      m.validates_format_of :name, :with => /\A[^\s;,]+\Z/, :on => :create, :message => "cannot have whitespace, commas, or semicolons"
#      validates_format_of :name, :with => /^(Anonymous|[Aa]dministrator)/, :on => :create, :message => "this is a disallowed username"
      m.validates_uniqueness_of :name, :case_sensitive => false, :on => :create
      m.after_save :update_cached_name if CONFIG["enable_caching"]
    end

    def pretty_name
      name.tr("_", " ")
    end

    def update_cached_name
      Rails.cache.write("user_name:#{id}", name)
    end
  end

  module UserApiMethods
    def to_xml(options = {})
      options[:indent] ||= 2
      xml = options[:builder] ||= Builder::XmlMarkup.new(:indent => options[:indent])
      xml.post(:name => name, :id => id) do
        blacklisted_tags_array.each do |t|
          xml.blacklisted_tag(:tag => t)
        end

        yield options[:builder] if block_given?
      end
    end

    def to_json(*args)
      {:name => name, :blacklisted_tags => blacklisted_tags_array, :id => id}.to_json(*args)
    end

    def user_info_cookie
      [id, level, use_browser ? "1":"0"].join(";");
    end
  end

  def self.find_by_name_nocase(name)
    return User.find(:first, :conditions => ["lower(name) = lower(?)", name])
  end

  module UserTagMethods
    def uploaded_tags(options = {})
      type = options[:type]

      if CONFIG["enable_caching"]
        uploaded_tags = Rails.cache.read("uploaded_tags/#{id}/#{type}")
        return uploaded_tags unless uploaded_tags == nil
      end

      if Rails.env == "test"
        # disable filtering in test mode to simplify tests
        popular_tags = ""
      else
        popular_tags = select_values_sql("SELECT id FROM tags WHERE tag_type = #{CONFIG['tag_types']['General']} ORDER BY post_count DESC LIMIT 8").join(", ")
        popular_tags = "AND pt.tag_id NOT IN (#{popular_tags})" unless popular_tags.blank?
      end

      if type
        sql = <<-EOS
          SELECT (SELECT name FROM tags WHERE id = pt.tag_id) AS tag, COUNT(*) AS count
          FROM posts_tags pt, tags t, posts p
          WHERE p.user_id = #{id}
          AND p.id = pt.post_id
          AND pt.tag_id = t.id
          #{popular_tags}
          AND t.tag_type = #{type.to_i}
          GROUP BY pt.tag_id
          ORDER BY count DESC
          LIMIT 6
        EOS
      else
        sql = <<-EOS
          SELECT (SELECT name FROM tags WHERE id = pt.tag_id) AS tag, COUNT(*) AS count
          FROM posts_tags pt, posts p
          WHERE p.user_id = #{id}
          AND p.id = pt.post_id
          #{popular_tags}
          GROUP BY pt.tag_id
          ORDER BY count DESC
          LIMIT 6
        EOS
      end

      uploaded_tags = select_all_sql(sql)

      if CONFIG["enable_caching"]
        Rails.cache.write("uploaded_tags/#{id}/#{type}", uploaded_tags, :expires_in => 1.day)
      end

      return uploaded_tags
    end

    def voted_tags(options = {})
      type = options[:type]

      if CONFIG["enable_caching"]
        favorite_tags = Rails.cache.read("favorite_tags/#{id}/#{type}")
        return favorite_tags unless favorite_tags == nil
      end

      if Rails.env == "test"
        # disable filtering in test mode to simplify tests
        popular_tags = ""
      else
        popular_tags = select_values_sql("SELECT id FROM tags WHERE tag_type = #{CONFIG['tag_types']['General']} ORDER BY post_count DESC LIMIT 8").join(", ")
        popular_tags = "AND pt.tag_id NOT IN (#{popular_tags})" unless popular_tags.blank?
      end

      if type
        sql = <<-EOS
          SELECT (SELECT name FROM tags WHERE id = pt.tag_id) AS tag, SUM(v.score) AS sum
          FROM posts_tags pt, tags t, post_votes v
          WHERE v.user_id = #{id}
          AND v.post_id = pt.post_id
          AND pt.tag_id = t.id
          #{popular_tags}
          AND t.tag_type = #{type.to_i}
          GROUP BY pt.tag_id
          ORDER BY sum DESC
          LIMIT 6
        EOS
      else
        sql = <<-EOS
          SELECT (SELECT name FROM tags WHERE id = pt.tag_id) AS tag, SUM(v.score) AS sum
          FROM posts_tags pt, post_votes v
          WHERE v.user_id = #{id}
          AND v.post_id = pt.post_id
          #{popular_tags}
          GROUP BY pt.tag_id
          ORDER BY sum DESC
          LIMIT 6
        EOS
      end

      favorite_tags = select_all_sql(sql)

      if CONFIG["enable_caching"]
        Rails.cache.write("favorite_tags/#{id}/#{type}", favorite_tags, :expires_in => 1.day)
      end

      return favorite_tags
    end
  end

  module UserPostMethods
    def recent_uploaded_posts
      Post.find_by_sql("SELECT p.* FROM posts p WHERE p.user_id = #{id} AND p.status <> 'deleted' ORDER BY p.id DESC LIMIT 6")
    end

    def recent_favorite_posts
      Post.find_by_sql("SELECT p.* FROM posts p, post_votes v WHERE p.id = v.post_id AND v.user_id = #{id} AND v.score = 3 AND p.status <> 'deleted' ORDER BY v.id DESC LIMIT 6")
    end

    def favorite_post_count(options = {})
      PostVotes.count_by_sql("SELECT COUNT(*) FROM post_votes v WHERE v.user_id = #{id} AND v.score = 3")
    end

    def post_count
      @post_count ||= Post.count(:conditions => ["user_id = ? AND status = 'active'", id])
    end

    def held_post_count
      version = Rails.cache.read("$cache_version").to_i
      key = "held-post-count/v=#{version}/u=#{self.id}"

      return Rails.cache.fetch(key) {
        Post.count(:conditions => ["user_id = ? AND is_held AND status <> 'deleted'", self.id])
      }.to_i
    end
  end

  module UserLevelMethods
    def self.included(m)
      m.extend(ClassMethods)
      m.attr_protected :level
      m.before_create :set_role
    end

    def pretty_level
      return CONFIG["user_levels"].invert[self.level]
    end

    def set_role
      if User.first.nil?
        self.level = CONFIG["user_levels"]["Admin"]
      elsif CONFIG["enable_account_email_activation"]
        self.level = CONFIG["user_levels"]["Unactivated"]
      else
        self.level = CONFIG["starting_level"]
      end

      self.last_logged_in_at = Time.now
    end

    def has_permission?(record, foreign_key = :user_id)
      if is_mod_or_higher?
        true
      elsif record.respond_to?(foreign_key)
        record.__send__(foreign_key) == id
      else
        false
      end
    end

    # Return true if this user can change the specified attribute.
    #
    # If record is an ActiveRecord object, returns true if the change is allowed to complete.
    #
    # If record is an ActiveRecord class (eg. Pool rather than an actual pool), returns
    # false if the user would never be allowed to make this change for any instance of the
    # object, and so the option should not be presented.
    #
    # For example, can_change(Pool, :description) returns true (unless the user level
    # is too low to change any pools), but can_change(Pool.find(1), :description) returns
    # false if that specific pool is locked.
    #
    # attribute usually corresponds with an actual attribute in the class, but any value
    # can be used.
    def can_change?(record, attribute)
      method = "can_change_#{attribute.to_s}?"
      if is_mod_or_higher?
        true
      elsif record.respond_to?(method)
        record.__send__(method, self)
      elsif record.respond_to?(:can_change?)
        record.can_change?(self, attribute)
      else
        true
      end
    end

    # Defines various convenience methods for finding out the user's level
    CONFIG["user_levels"].each do |name, value|
      normalized_name = name.downcase.gsub(/ /, "_")
      define_method("is_#{normalized_name}?") do
        self.level == value
      end

      define_method("is_#{normalized_name}_or_higher?") do
        self.level >= value
      end

      define_method("is_#{normalized_name}_or_lower?") do
        self.level <= value
      end
    end


    module ClassMethods
      def get_user_level(level)
        if not @user_level then
          @user_level = {}
          CONFIG["user_levels"].each do |name, value|
            normalized_name = name.downcase.gsub(/ /, "_").to_sym
            @user_level[normalized_name] = value
          end
        end
        @user_level[level]
      end
    end
  end

  module UserInviteMethods
    class NoInvites < Exception ; end
    class HasNegativeRecord < Exception ; end

    def invite!(name, level)
      if invite_count <= 0
        raise NoInvites
      end

      if level.to_i >= CONFIG["user_levels"]["Contributor"]
        level = CONFIG["user_levels"]["Contributor"]
      end

      invitee = User.find_by_name(name)

      if invitee.nil?
        raise ActiveRecord::RecordNotFound
      end

      if UserRecord.exists?(["user_id = ? AND is_positive = false AND reported_by IN (SELECT id FROM users WHERE level >= ?)", invitee.id, CONFIG["user_levels"]["Mod"]]) && !is_admin?
        raise HasNegativeRecord
      end

      transaction do
        if level == CONFIG["user_levels"]["Contributor"]
          Post.find(:all, :conditions => ["user_id = ? AND status = 'pending'", id]).each do |post|
            post.approve!(id)
          end
        end
        invitee.level = level
        invitee.invited_by = id
        invitee.save
        decrement! :invite_count
      end
    end

    def self.included(m)
      m.attr_protected :invite_count
    end
  end

  module UserAvatarMethods
    module ClassMethods
      # post_id is being destroyed.  Clear avatar_post_ids for this post, so we won't use
      # avatars from this post.  We don't need to actually delete the image.
      def clear_avatars(post_id)
        execute_sql("UPDATE users SET avatar_post_id = NULL WHERE avatar_post_id = ?", post_id)
      end
    end

    def self.included(m)
      m.extend(ClassMethods)
      m.belongs_to :avatar_post, :class_name => "Post"
    end

    def avatar_url
      CONFIG["url_base"] + "/data/avatars/#{self.id}.jpg"
    end

    def has_avatar?
      return (not self.avatar_post_id.nil?)
    end

    def avatar_path
      "#{Rails.root}/public/data/avatars/#{self.id}.jpg"
    end

    def set_avatar(params)
      post = Post.find(params[:post_id])
      if not post.can_be_seen_by?(self)
        errors.add(:access, "denied")
        return false
      end

      if params[:top].to_f < 0 or params[:top].to_f > 1 or
        params[:bottom].to_f < 0 or params[:bottom].to_f > 1 or
        params[:left].to_f < 0 or params[:left].to_f > 1 or
        params[:right].to_f < 0 or params[:right].to_f > 1 or
        params[:top] >= params[:bottom] or
        params[:left] >= params[:right]
      then
        errors.add(:parameter, "error")
        return false
      end

      tempfile_path = "#{Rails.root}/public/data/#{Process.pid}.avatar.jpg"

      def reduce_and_crop(image_width, image_height, params)
        cropped_image_width = image_width * (params[:right].to_f - params[:left].to_f)
        cropped_image_height = image_height * (params[:bottom].to_f - params[:top].to_f)

        size = Danbooru.reduce_to({:width=>cropped_image_width, :height=>cropped_image_height}, {:width=>CONFIG["avatar_max_width"], :height=>CONFIG["avatar_max_height"]}, 1, true)
        size[:crop_top] = image_height * params[:top].to_f
        size[:crop_bottom] = image_height * params[:bottom].to_f
        size[:crop_left] = image_width * params[:left].to_f
        size[:crop_right] = image_width * params[:right].to_f
        size
      end

      use_sample = post.has_sample?
      if use_sample
        image_path = post.sample_path
        image_ext = "jpg"
        size = reduce_and_crop(post.sample_width, post.sample_height, params)

        # If we're cropping from a very small region in the sample, use the full
        # image instead, to get a higher quality image.
        if size[:crop_bottom] - size[:crop_top] < CONFIG["avatar_max_height"] or
          size[:crop_right] - size[:crop_left] < CONFIG["avatar_max_width"] then
          use_sample = false
        end
      end

      if not use_sample
        image_path = post.file_path
        image_ext = post.file_ext
        size = reduce_and_crop(post.width, post.height, params)
      end

      begin
        Danbooru.resize(image_ext, image_path, tempfile_path, size, 95)
      rescue Exception => x
        FileUtils.rm_f(tempfile_path)

        errors.add "avatar", "couldn't be generated (#{x})"
        return false
      end

      FileUtils.mv(tempfile_path, avatar_path)
      FileUtils.chmod(0775, avatar_path)

      self.update_attributes(
        :avatar_post_id => params[:post_id],
        :avatar_top => params[:top],
        :avatar_bottom => params[:bottom],
        :avatar_left => params[:left],
        :avatar_right => params[:right],
        :avatar_width => size[:width],
        :avatar_height => size[:height],
        :avatar_timestamp => Time.now)
    end
  end


  module UserTagSubscriptionMethods
    def self.included(m)
      m.has_many :tag_subscriptions, :dependent => :delete_all, :order => "name"
    end

    def tag_subscriptions_text=(text)
      User.transaction do
        tag_subscriptions.clear

        text.scan(/\S+/).each do |new_tag_subscription|
          tag_subscriptions.create(:tag_query => new_tag_subscription)
        end
      end
    end

    def tag_subscriptions_text
      tag_subscriptions_text.map(&:tag_query).sort.join(" ")
    end

    def tag_subscription_posts(limit, name)
      TagSubscription.find_posts(id, name, limit)
    end
  end

  module UserLanguageMethods
    def self.included(m)
      m.validates_format_of :language, :with => /^([a-z\-]+)|$/
      m.validates_format_of :secondary_languages, :with => /^([a-z\-]+(,[a-z\0]+)*)?$/
      m.before_validation :commit_secondary_languages
    end

    def secondary_language_array=(langs)
      @secondary_languages = langs
    end

    def secondary_language_array
      return @secondary_languages if @secondary_languages
      return self.secondary_languages.split(",")
    end

    def commit_secondary_languages
      return if not @secondary_languages

      if @secondary_languages.include?("none") then
        self.secondary_languages = ""
      else
        self.secondary_languages = @secondary_languages.join(",")
      end
    end
  end

  validates_presence_of :email, :on => :create if CONFIG["enable_account_email_activation"]
  validates_uniqueness_of :email, :case_sensitive => false, :on => :create, :if => lambda {|rec| not rec.email.empty?}
  before_create :set_show_samples if CONFIG["show_samples"]
  has_one :ban

  include UserBlacklistMethods
  include UserAuthenticationMethods
  include UserPasswordMethods
  include UserCountMethods
  include UserNameMethods
  include UserApiMethods
  include UserTagMethods
  include UserPostMethods
  include UserLevelMethods
  include UserInviteMethods
  include UserAvatarMethods
  include UserTagSubscriptionMethods
  include UserLanguageMethods

  @salt = CONFIG["user_password_salt"]

  class << self
    attr_accessor :salt
  end

  # For compatibility with AnonymousUser class
  def is_anonymous?
    false
  end

  def invited_by_name
    self.class.find_name(invited_by)
  end

  def similar_users
    # This uses a naive cosine distance formula that is very expensive to calculate.
    # TODO: look into alternatives, like SVD.
    sql = <<-EOS
      SELECT
        f0.user_id as user_id,
        COUNT(*) / (SELECT sqrt((SELECT COUNT(*) FROM post_votes WHERE user_id = f0.user_id) * (SELECT COUNT(*) FROM post_votes WHERE user_id = #{id}))) AS similarity
      FROM
        vote v0,
        vote v1,
        users u
      WHERE
        v0.post_id = v1.post_id
        AND v1.user_id = #{id}
        AND v0.user_id <> #{id}
        AND u.id = v0.user_id
      GROUP BY v0.user_id
      ORDER BY similarity DESC
      LIMIT 6
    EOS

    return select_all_sql(sql)
  end

  def set_show_samples
    self.show_samples = true
  end

  def self.generate_sql(params)
    return Nagato::Builder.new do |builder, cond|
      if params[:name]
        cond.add "name ILIKE ? ESCAPE E'\\\\'", "%" + params[:name].tr(" ", "_").to_escaped_for_sql_like + "%"
      end

      if params[:level] && params[:level] != "any"
        cond.add "level = ?", params[:level]
      end

      cond.add_unless_blank "id = ?", params[:id]

      case params[:order]
      when "name"
        builder.order "lower(name)"

      when "posts"
        builder.order "(SELECT count(*) FROM posts WHERE user_id = users.id) DESC"

      when "favorites"
        builder.order "(SELECT count(*) FROM favorites WHERE user_id = users.id) DESC"

      when "notes"
        builder.order "(SELECT count(*) FROM note_versions WHERE user_id = users.id) DESC"

      else
        builder.order "id DESC"
      end
    end.to_hash
  end
end

