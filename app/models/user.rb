require "digest/sha1"

class User < ActiveRecord::Base
  has_many :user_logs
  has_many :post_votes
  attr_accessor :current_email

  def set_api_key
    self.api_key = SecureRandom.urlsafe_base64
  end

  def self.authenticate_with_api_key(username, api_key)
    where(:name => username, :api_key => api_key).first
  end

  def log(ip)
    Rails.cache.fetch({ :type => :user_logs, :id => id, :ip => ip }, :expires_in => 10.minutes) do
      Rails.cache.fetch({ :type => :user_logs, :id => :all }, :expires_in => 1.day) do
        UserLog.where("created_at < ?", 3.days.ago).delete_all
      end
      begin
        log_entry = user_logs.find_or_initialize_by(:ip_addr => ip)
        log_entry.created_at = Time.now
        log_entry.save
      # Once in a blue moon there will be race condition on find_or_initialize
      # resulting unique key constraint violation.
      # It doesn't really affect anything so just ignore that error.
      rescue ActiveRecord::RecordNotUnique
        true
      end
    end
  end

  module UserBlacklistMethods
    # TODO: I don't see the advantage of normalizing these. Since commas are illegal
    # characters in tags, they can be used to separate lines (with whitespace separating
    # tags). Denormalizing this into a field in users would save a SQL query.
    def self.included(m)
      m.after_save :commit_blacklists
      m.after_create :set_default_blacklisted_tags
      m.has_many :user_blacklisted_tags, lambda { order "id" }, :dependent => :delete_all
    end

    attr_writer :blacklisted_tags

    def blacklisted_tags
      blacklisted_tags_array.join("\n") + "\n"
    end

    def blacklisted_tags_array
      if user_blacklisted_tags.loaded?
        user_blacklisted_tags.map(&:tags)
      else
        user_blacklisted_tags.pluck(:tags)
      end
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
        UserBlacklistedTag.create(:user_id => id, :tags => b)
      end
    end
  end

  module UserAuthenticationMethods
    module ClassMethods
      def authenticate(name, pass)
        authenticate_hash(name, sha1(pass))
      end

      def authenticate_hash(name, pass)
        where("LOWER(users.name) = LOWER(?)", name).where(:password_hash => pass).first
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
    attr_accessor :password, :current_password

    def self.included(m)
      m.before_save :encrypt_password
      m.validates_length_of :password, :minimum => 5, :if => lambda { |rec| rec.password }
      m.validates_confirmation_of :password
      # Changing password requires current password.
      m.validate :validate_current_password
    end

    def validate_current_password
      # First test to see if it's creating new user (no password_hash)
      # or updating user. The second is to see if the action involves
      # updating password (which requires this validation).
      if password_hash && (password || (self.email_changed? || current_email))
        if current_password.blank?
          errors.add :current_password, :blank
        elsif User.authenticate(name, current_password).nil?
          errors.add :current_password, :invalid
        end
      end
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
      execute_sql("UPDATE users SET password_hash = ? WHERE id = ?", User.sha1(pass), id)
      pass
    end
  end

  module UserNameMethods
    module ClassMethods
      def find_name(user_id)
        (select(:name).find_by(:id => user_id) || AnonymousUser.new).name
      end

      def find_by_name(name)
        find_by("LOWER(name) = LOWER(?)", name)
      end
    end

    def self.included(m)
      m.extend(ClassMethods)
      m.validates_length_of :name, :within => 2..20, :on => :create
      m.validates_format_of :name, :with => /\A[^\s;,]+\Z/, :on => :create, :message => "cannot have whitespace, commas, or semicolons"
      #      validates_format_of :name, :with => /^(Anonymous|[Aa]dministrator)/, :on => :create, :message => "this is a disallowed username"
      m.validates_uniqueness_of :name, :case_sensitive => false, :on => :create
      m.after_save :update_cached_name
    end

    # FIXME: nuke this
    def pretty_name
      name
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

    def as_json(*args)
      { :name => name, :blacklisted_tags => blacklisted_tags_array, :id => id }.as_json(*args)
    end

    def user_info_cookie
      [id, level, use_browser ? "1" : "0"].join(";")
    end
  end

  module UserTagMethods
    def uploaded_tags(options = {})
      type = options[:type]

      uploaded_tags = Rails.cache.read("uploaded_tags/#{id}/#{type}")
      return uploaded_tags unless uploaded_tags.nil?

      if Rails.env == "test"
        # disable filtering in test mode to simplify tests
        popular_tags = ""
      else
        popular_tags = select_values_sql("SELECT id FROM tags WHERE tag_type = #{CONFIG["tag_types"]["General"]} ORDER BY post_count DESC LIMIT 8").join(", ")
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

      Rails.cache.write("uploaded_tags/#{id}/#{type}", uploaded_tags, :expires_in => 1.day)

      uploaded_tags
    end

    def voted_tags(options = {})
      type = options[:type]

      favorite_tags = Rails.cache.read("favorite_tags/#{id}/#{type}")
      return favorite_tags unless favorite_tags.nil?

      if Rails.env == "test"
        # disable filtering in test mode to simplify tests
        popular_tags = ""
      else
        popular_tags = select_values_sql("SELECT id FROM tags WHERE tag_type = #{CONFIG["tag_types"]["General"]} ORDER BY post_count DESC LIMIT 8").join(", ")
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

      Rails.cache.write("favorite_tags/#{id}/#{type}", favorite_tags, :expires_in => 1.day)

      favorite_tags
    end
  end

  module UserPostMethods
    extend ActiveSupport::Concern

    included do
      has_many :posts
    end

    def recent_uploaded_posts
      posts.available.order(:id => :desc).limit(6)
    end

    def recent_favorite_posts
      Post.available.joins(:post_votes).where(:post_votes => { :user_id => id, :score => 3 }).order("post_votes.id DESC").limit(6)
    end

    def favorite_post_count(_options = {})
      post_votes.where(:score => 3).count
    end

    def post_count
      @post_count ||= posts.where(:status => "active").count
    end

    def held_post_count
      posts.available.where(:is_held => true).count
    end
  end

  module UserLevelMethods
    def self.included(m)
      m.extend(ClassMethods)
      m.before_create :set_role
    end

    def pretty_level
      CONFIG["user_levels"].invert[level]
    end

    def set_role
      self.level = if User.exists?
                     if CONFIG["enable_account_email_activation"]
                       CONFIG["user_levels"]["Unactivated"]
                     else
                       CONFIG["starting_level"]
                     end
                   else
                     CONFIG["user_levels"]["Admin"]
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
      method = "can_change_#{attribute}?"
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
        level == value
      end

      define_method("is_#{normalized_name}_or_higher?") do
        level >= value
      end

      define_method("is_#{normalized_name}_or_lower?") do
        level <= value
      end
    end

    module ClassMethods
      def get_user_level(level)
        unless @user_level
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
    class NoInvites < Exception; end
    class HasNegativeRecord < Exception; end

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
          Post.where(:status => "pending", :user_id => id).find_each do |post|
            post.approve!(id)
          end
        end
        invitee.level = level
        invitee.invited_by = id
        invitee.save
        decrement! :invite_count
      end
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
      CONFIG["url_base"] + "/data/avatars/#{id}.jpg"
    end

    def has_avatar?
      (!avatar_post_id.nil?)
    end

    def avatar_path
      "#{Rails.root}/public/data/avatars/#{id}.jpg"
    end

    def set_avatar(params)
      post = Post.find(params[:post_id])
      unless post.can_be_seen_by?(self)
        errors.add(:access, "denied")
        return false
      end

      [:top, :bottom, :left, :right].each { |d| params[d] = params[d].to_f }

      if params[:top] < 0 || params[:top] > 1 ||
          params[:bottom] < 0 || params[:bottom] > 1 ||
          params[:left] < 0 || params[:left] > 1 ||
          params[:right] < 0 || params[:right] > 1 ||
          params[:top] >= params[:bottom] ||
          params[:left] >= params[:right]

        errors.add(:parameter, "error")
        return false
      end

      tempfile_path = "#{Rails.root}/public/data/#{SecureRandom.random_number(2**32)}.avatar.jpg"

      def reduce_and_crop(image_width, image_height, params)
        cropped_image_width = image_width * (params[:right] - params[:left])
        cropped_image_height = image_height * (params[:bottom] - params[:top])

        size = Moebooru::Resizer.reduce_to({ :width => cropped_image_width, :height => cropped_image_height }, { :width => CONFIG["avatar_max_width"], :height => CONFIG["avatar_max_height"] }, 1, true)
        size[:crop_top] = image_height * params[:top]
        size[:crop_bottom] = image_height * params[:bottom]
        size[:crop_left] = image_width * params[:left]
        size[:crop_right] = image_width * params[:right]
        size
      end

      use_sample = post.has_sample?
      if use_sample
        image_path = post.sample_path
        image_ext = "jpg"
        size = reduce_and_crop(post.sample_width, post.sample_height, params)

        # If we're cropping from a very small region in the sample, use the full
        # image instead, to get a higher quality image.
        if size[:crop_bottom] - size[:crop_top] < CONFIG["avatar_max_height"] ||
            size[:crop_right] - size[:crop_left] < CONFIG["avatar_max_width"]
          use_sample = false
        end
      end

      unless use_sample
        image_path = post.file_path
        image_ext = post.file_ext
        size = reduce_and_crop(post.width, post.height, params)
      end

      begin
        Moebooru::Resizer.resize(image_ext, image_path, tempfile_path, size, 95)
      rescue => x
        FileUtils.rm_f(tempfile_path)

        errors.add "avatar", "couldn't be generated (#{x})"
        return false
      end

      FileUtils.mkdir_p(File.dirname(avatar_path))
      FileUtils.mv(tempfile_path, avatar_path)
      FileUtils.chmod(0775, avatar_path)

      update_attributes(
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
      m.has_many :tag_subscriptions, lambda { order "name" }, :dependent => :delete_all
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
      m.validates_format_of :language, :with => /\A([a-z\-]+)|\z/
      m.validates_format_of :secondary_languages, :with => /\A([a-z\-]+(,[a-z\0]+)*)?\z/
      m.before_validation :commit_secondary_languages
    end

    attr_writer :secondary_language_array

    def secondary_language_array
      @secondary_language_array || secondary_languages.split(",")
    end

    def commit_secondary_languages
      return unless secondary_language_array

      if secondary_language_array.include?("none")
        self.secondary_languages = ""
      else
        self.secondary_languages = secondary_language_array.join(",")
      end
    end
  end

  validates_presence_of :email, :on => :create if CONFIG["enable_account_email_activation"]
  validates_uniqueness_of :email, :case_sensitive => false, :on => :create, :if => lambda { |rec| !rec.email.empty? }
  before_create :set_show_samples if CONFIG["show_samples"]
  has_one :ban

  include UserBlacklistMethods
  include UserAuthenticationMethods
  include UserPasswordMethods
  include UserNameMethods
  include UserApiMethods
  include UserTagMethods
  include UserPostMethods
  include UserLevelMethods
  include UserInviteMethods
  include UserAvatarMethods
  include UserTagSubscriptionMethods
  include UserLanguageMethods

  @salt = CONFIG["password_salt"]

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

    select_all_sql(sql)
  end

  def set_show_samples
    self.show_samples = true
  end

  def self.with_params(params)
    res = all

    res = res.where("name ILIKE ?", "*#{params[:name].tr(" ", "_")}*".to_escaped_for_sql_like) if params[:name]
    res = res.where(:level => params[:level]) if params[:level] && params[:level] != "any"
    res = res.where(:id => params[:id]) if params[:id]

    order =
      case params[:order]
      when "name" then "LOWER(name)"
      when "posts" then "(SELECT count(*) FROM posts WHERE user_id = users.id) DESC"
      when "favorites" then "(SELECT count(*) FROM favorites WHERE user_id = users.id) DESC"
      when "notes" then "(SELECT count(*) FROM note_versions WHERE user_id = users.id) DESC"
      else "id DESC"
      end

    res.order(order)
  end

  # FIXME: ensure not used and then nuke
  def self.generate_sql(params)
    Nagato::Builder.new do |builder, cond|
      if params[:name]
        cond.add "name ILIKE ? ESCAPE E'\\\\'", "%" + params[:name].tr(" ", "_").to_escaped_for_sql_like + "%"
      end

      if params[:level] && params[:level] != "any"
        cond.add "level = ?", params[:level].to_i
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
