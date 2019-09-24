class Post < ApplicationRecord
  STATUSES = %w(active pending flagged deleted)

  define_callbacks :delete
  define_callbacks :undelete
  has_many :notes, lambda { order "id DESC" }
  has_one :flag_detail, :class_name => "FlaggedPostDetail"
  belongs_to :user
  before_validation :set_random!, :on => :create
  before_create :set_index_timestamp!
  belongs_to :approver, :class_name => "User"
  attr_accessor :updater_ip_addr, :updater_user_id
  attr_accessor :metatag_flagged
  has_many :post_votes
  has_many :avatars, :class_name => "User", :foreign_key => "avatar_post_id"
  set_callback :delete, :before, :clear_avatars
  after_save :commit_flag
  has_and_belongs_to_many :_tags, :class_name => "Tag"
  scope :available, lambda { where.not :status => "deleted" }
  scope :has_any_tags, lambda { |tags| where("posts.tags_array && ARRAY[?]::varchar[]", Array(tags)) }
  scope :has_all_tags, lambda { |tags| where("posts.tags_array @> ARRAY[?]::varchar[]", Array(tags)) }
  scope :flagged, lambda { where "status = ?", "flagged" }

  def self.slow_has_all_tags(tags)
    p = Post.scoped
    t_ids = Tag.where(:name => tags).pluck(:id)
    t_ids.each do |t_id|
      p = p.where(:id => PostsTag.where(:tag_id => t_id).select(:post_id))
    end
    p
  end

  def self.slow_has_any_tags(tags)
    t_ids = Tag.where(:name => tags).pluck(:id)
    Post.where(:id => PostsTag.where(:tag_id => t_ids).select(:post_id))
  end

  def next_id
    Post.available.where("posts.id > ?", id).minimum(:id)
  end

  def previous_id
    Post.available.where("posts.id < ?", id).maximum(:id)
  end

  include Post::SqlMethods
  include Post::CommentMethods
  include Post::ImageStoreMethods
  include Post::VoteMethods
  include Post::TagMethods
  include Post::CountMethods
  include Post::CacheMethods
  include Post::ParentMethods
  include Post::FileMethods
  include Post::ChangeSequenceMethods
  include Post::RatingMethods
  include Post::StatusMethods
  include Post::ApiMethods
  include Post::MirrorMethods
  include Post::FrameMethods

  def destroy_with_reason(reason, current_user)
    transaction do
      flag!(reason, current_user.id)

      if flag_detail
        flag_detail.update(:is_resolved => true)
      end

      delete
    end
  end

  def self.destroy_with_reason(id, reason, current_user)
    post = Post.find(id)
    post.destroy_with_reason(reason, current_user)
  end

  def delete
    run_callbacks :delete do
      update(:status => "deleted")
    end
  end

  def undelete
    return if status == "active"
    run_callbacks :undelete do
      update(:status => "active")
    end
  end

  def can_user_delete?(user)
    return false unless user.has_permission?(self)

    return false if !user.is_mod_or_higher? && !is_held && created_at < 1.day.ago

    true
  end

  def clear_avatars
    User.clear_avatars(id)
  end

  def set_random!
    self.random = rand
  end

  def set_index_timestamp!
    self.index_timestamp = (self.created_at ||= Time.now)
  end

  def set_flag_detail(reason, creator_id)
    if flag_detail
      flag_detail.update(:reason => reason, :user_id => creator_id, :created_at => Time.now)
    else
      create_flag_detail!(:reason => reason, :user_id => creator_id, :is_resolved => false)
    end
  end

  def flag!(reason, creator_id)
    transaction do
      update(:status => "flagged")
      set_flag_detail(reason, creator_id)
    end
  end

  # If the flag_post metatag was used and the current user has access, flag the post.
  def commit_flag
    return if metatag_flagged.nil?
    return unless Thread.current["danbooru-user"].is_mod_or_higher?
    return if status != "active"

    self.flag!(metatag_flagged, Thread.current["danbooru-user"].id)
  end

  def approve!(approver_id)
    old_status = status

    if flag_detail
      flag_detail.update(:is_resolved => true)
    end

    update(:status => "active", :approver_id => approver_id)

    # Don't bump posts if the status wasn't "pending"; it might be "flagged".
    if old_status == "pending" && CONFIG["hide_pending_posts"]
      touch_index_timestamp
    end
    # Always try to save to trigger history logging.
    self.save!
  end

  def voted_by
    # FIXME: shouldn't include user_blacklist_tags at all (used by API return).
    @voted_by ||=
      User.select(:name, :id, "post_votes.score AS vote_score")
        .joins(:post_votes)
        .includes(:user_blacklisted_tags)
        .where(:post_votes => { :post_id => id })
        .order("post_votes.updated_at DESC")
        .group_by(&:vote_score)
  end

  def favorited_by
    voted_by[3] || []
  end

  def author
    (user || AnonymousUser.new).name
  end

  def delete_from_database
    delete_file
    execute_sql("DELETE FROM posts WHERE id = ?", id)
  end

  def active_notes
    notes.select(&:is_active?)
  end

  STATUSES.each do |x|
    define_method("is_#{x}?") do
      return status == x
    end
  end

  def can_be_seen_by?(user, options = {})
    if !options[:show_deleted] && status == "deleted"
      return false
    end
    CONFIG["can_see_post"].call(user, self)
  end

  def self.new_deleted?(user)
    conds = []
    conds += ["creator_id <> %d" % [user.id]] unless user.is_anonymous?

    newest_topic = ForumPost.where(conds).order(:id => :desc).select(:created_at).take
    return false if newest_topic.nil?
    newest_topic.created_at > user.last_forum_topic_read_at
  end

  def normalized_source
    if source =~ /(pixiv\.net|pximg\.net)\/img/
      img_id = source[/(\d+)(_s|_m|(_big)?_p\d+)?\.\w+(\?\d+)?\z/, 1]
      "https://www.pixiv.net/artworks/#{img_id}"
    elsif source =~ /\Ahttps?:\/\//i
      source
    else
      "http://#{source}"
    end
  end

  def service
    CONFIG["local_image_service"]
  end

  def service_icon
    "/favicon.ico"
  end

  def self.refresh_tags_array
    max_id = maximum(:id)

    (0..((max_id/1000).floor)).each do |i|
      start_id = i * 1000 + 1
      end_id = (i + 1) * 1000

      Rails.logger.info "Updating tags array for post #{start_id}..#{end_id} of #{max_id}"
      where('id BETWEEN ? AND ?', start_id, end_id).update_all "tags_array = string_to_array(cached_tags, ' ')"
    end
  end
end
