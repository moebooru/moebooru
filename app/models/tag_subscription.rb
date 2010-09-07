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
  
  def add_posts!(post_ids)
    if cached_post_ids.blank?
      update_attribute :cached_post_ids, post_ids.join(",")
    else
      update_attribute :cached_post_ids, "#{post_id.join(',')},#{cached_post_ids}"
    end
  end
  
  def prune!
    hoge = cached_post_ids.split(/,/)
    
    if hoge.size > CONFIG["tag_subscription_post_limit"] / 3
      update_attribute :cached_post_ids, hoge[0, CONFIG["tag_subscription_post_limit"] / 3].join(",")
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
          tags = tag_subscription.tag_query.scan(/\S+/)
          tags.each do |tag|
            post_ids = Post.find_by_tags(tag, :limit => CONFIG["tag_subscription_post_limit"] / 3, :select => "p.id", :order => "p.id desc").map(&:id)
            tag_subscription.add_posts!(post_ids)
          end
          tag_subscription.prune!
        rescue Exception => x
          # fail silently
        end
        sleep 1
      end
    end
  end
end
