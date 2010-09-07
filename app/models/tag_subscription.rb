class TagSubscription < ActiveRecord::Base
  belongs_to :user
  before_create :initialize_post_ids
  before_save :normalize_name
  named_scope :visible, :conditions => "is_visible_on_profile = TRUE"

  def normalize_name
    self.name = name.gsub(/\W/, "_")
  end
  
  def initialize_post_ids
    if user.is_privileged_or_higher?
      self.cached_post_ids = Post.find_by_tags(tag_query, :limit => CONFIG["tag_subscription_post_limit"] / 3, :select => "p.id", :order => "p.id desc").map(&:id).uniq.join(",")
    end
  end
  
  def self.find_post_ids(user_id, name = nil, limit = CONFIG["tag_subscription_post_limit"])
    if name
      find(:all, :conditions => ["user_id = ? AND name ILIKE ? ESCAPE E'\\\\'", user_id, name.to_escaped_for_sql_like + "%"], :select => "id, cached_post_ids").map {|x| x.cached_post_ids.split(/,/)}.flatten.uniq.sort.reverse.slice(0, limit)
    else
      find(:all, :conditions => ["user_id = ?", user_id], :select => "id, cached_post_ids").map {|x| x.cached_post_ids.split(/,/)}.flatten.uniq.sort.reverse.slice(0, limit)
    end
  end
  
  def self.find_posts(user_id, name = nil, limit = CONFIG["tag_subscription_post_limit"])
    Post.find(:all, :conditions => ["id in (?)", find_post_ids(user_id, name, limit)], :order => "id DESC", :limit => limit)
  end
  
  def self.process_all
    find(:all).each do |tag_subscription|
      if tag_subscription.user.is_privileged_or_higher?
        begin
          TagSubscription.transaction do
            tags = tag_subscription.tag_query.scan(/\S+/)
            post_ids = []
            tags.each do |tag|
              post_ids += Post.find_by_tags(tag, :limit => CONFIG["tag_subscription_post_limit"] / 3, :select => "p.id", :order => "p.id desc").map(&:id)
            end
            tag_subscription.update_attribute(:cached_post_ids, post_ids.sort.reverse.slice(0, CONFIG["tag_subscription_post_limit"]).join(","))
          end
        rescue Exception => x
          # fail silently
        end
        sleep 1
      end
    end
  end
end
