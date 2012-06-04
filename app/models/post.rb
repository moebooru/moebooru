Dir["#{Rails.root}/app/models/post/**/*.rb"].each {|x| require_dependency x}

class Post < ActiveRecord::Base
  STATUSES = %w(active pending flagged deleted)
  
  define_callbacks :delete
  define_callbacks :undelete
  has_many :notes, :order => "id desc"
  has_one :flag_detail, :class_name => "FlaggedPostDetail"
  belongs_to :user
  before_validation :set_random!, :on => :create
  before_create :set_index_timestamp!
  belongs_to :approver, :class_name => "User"
  attr_accessor :updater_ip_addr, :updater_user_id
  attr_accessor :metatag_flagged
  has_many :avatars, :class_name => "User", :foreign_key => "avatar_post_id"
  set_callback :delete, :before, :clear_avatars
  after_save :commit_flag
  has_and_belongs_to_many :_tags, :class_name => 'Tag'
  scope :available, where('status <> ?', 'deleted')
  scope :has_any_tags, lambda { |tags| where('tags_index @@ ?', Array(tags).map { |t| t.to_escaped_for_tsquery }.join(' | ')) }
  scope :has_all_tags, lambda { |tags| where('tags_index @@ ?', Array(tags).map { |t| t.to_escaped_for_tsquery }.join(' & ')) }

  include PostSqlMethods
  include PostCommentMethods
  include PostImageStoreMethods
  include PostVoteMethods
  include PostTagMethods
  include PostCountMethods
  include PostCacheMethods if CONFIG["enable_caching"]
  include PostParentMethods if CONFIG["enable_parent_posts"]
  include PostFileMethods
  include PostChangeSequenceMethods
  include PostRatingMethods
  include PostStatusMethods
  include PostApiMethods
  include PostMirrorMethods
  include PostFrameMethods

  def destroy_with_reason(reason, current_user)
    Post.transaction do
      self.flag!(reason, current_user.id)
      if self.flag_detail
        self.flag_detail.update_attributes(:is_resolved => true)
      end
      self.delete
    end
  end

  def self.destroy_with_reason(id, reason, current_user)
    post = Post.find(id)
    return post.destroy_with_reason(reason, current_user)
  end

  def delete
    run_callbacks :delete do
      self.update_attributes(:status => "deleted")
    end
  end

  def undelete
    return if self.status == "active"
    run_callbacks :undelete do
      self.update_attributes(:status => "active")
    end
  end
  
  def can_user_delete?(user)
    if not user.has_permission?(self)
      return false
    end

    if not user.is_mod_or_higher? and Time.now - self.created_at > 1.day and not is_held
      return false
    end

    return true
  end

  def clear_avatars
    User.clear_avatars(self.id)
  end

  def set_random!
    self.random = rand;
  end

  def set_index_timestamp!
    self.index_timestamp = self.created_at = Time.now
  end

  def set_flag_detail(reason, creator_id)
    if flag_detail
      flag_detail.update_attributes(:reason => reason, :user_id => creator_id, :created_at => Time.now)
    else
      FlaggedPostDetail.create!(:post_id => id, :reason => reason, :user_id => creator_id, :is_resolved => false)
    end
  end

  def flag!(reason, creator_id)
    transaction do
      update_attributes(:status => "flagged")
      set_flag_detail(reason, creator_id)
    end
  end
  
  # If the flag_post metatag was used and the current user has access, flag the post.
  def commit_flag
    return if self.metatag_flagged.nil?
    return if not Thread.current["danbooru-user"].is_mod_or_higher?
    return if self.status != "active"

    self.flag!(self.metatag_flagged, Thread.current["danbooru-user"].id)
  end

  def approve!(approver_id)
    old_status = status

    if flag_detail
      flag_detail.update_attributes(:is_resolved => true)
    end
    
    update_attributes(:status => "active", :approver_id => approver_id)

    # Don't bump posts if the status wasn't "pending"; it might be "flagged".
    if old_status == "pending" and CONFIG["hide_pending_posts"] then
      touch_index_timestamp
      self.save!
    end
  end
  
  def voted_by
    # Cache results
    if @voted_by.nil?
      @voted_by = {}
      (1..3).each { |v|
        @voted_by[v] = User.find(:all, :joins => "JOIN post_votes v ON v.user_id = users.id", :select => "users.name, users.id", :conditions => ["v.post_id = ? and v.score = ?", self.id, v], :order => "v.updated_at DESC") || []
      }
    end

    return @voted_by
  end

  def favorited_by
    return voted_by[3]
  end

  def author
    return User.find_name(user_id)
  end
  
  def delete_from_database
    delete_file
    execute_sql("DELETE FROM posts WHERE id = ?", id)
  end
  
  def active_notes
    notes.select {|x| x.is_active?}
  end
  
  STATUSES.each do |x|
    define_method("is_#{x}?") do
      return status == x
    end
  end
  
  def can_be_seen_by?(user, options={})
    if not options[:show_deleted] and self.status == 'deleted'
      return false
    end
    CONFIG["can_see_post"].call(user, self)
  end
  
  def self.new_deleted?(user)
    conds = []
    conds += ["creator_id <> %d" % [user.id]] unless user.is_anonymous?

    newest_topic = ForumPost.find(:first, :order => "id desc", :limit => 1, :select => "created_at", :conditions => conds)
    return false if newest_topic == nil
    return newest_topic.created_at > user.last_forum_topic_read_at
  end

  def normalized_source
    if source =~ /pixiv\.net\/img\//
      img_id = source[/(\d+)\.\w+$/, 1]
      "http://www.pixiv.net/member_illust.php?mode=medium&illust_id=#{img_id}"
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
end
