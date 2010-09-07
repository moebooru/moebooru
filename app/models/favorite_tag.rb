class FavoriteTag < ActiveRecord::Base
  belongs_to :user
  before_create :initialize_post_ids
  before_save :normalize_name

  def normalize_name
    self.name = name.gsub(/\W/, "_")
  end

  def initialize_post_ids
    if user.is_privileged_or_higher?
      self.cached_post_ids = Post.find_by_tags(tag_query, :limit => 60, :select => "p.id").map(&:id).join(",")
    end
  end
  
  def interested?(post_id)
    begin
      Post.find_by_tags(tag_query + " id:#{post_id}").any?
    rescue Exception
      false
    end
  end
  
  def add_post!(post_id)
    if cached_post_ids.blank?
      update_attribute :cached_post_ids, post_id.to_s
    else
      update_attribute :cached_post_ids, "#{post_id},#{cached_post_ids}"
    end
  end
  
  def prune!
    hoge = cached_post_ids.split(/,/)
    
    if hoge.size > CONFIG["favorite_tag_post_limit"]
      update_attribute :cached_post_ids, hoge[0, CONFIG["favorite_tag_post_limit"]].join(",")
    end
  end
  
  def self.find_post_ids(user_id, favtag_name, limit = 60)
    if favtag_name
      find(:all, :conditions => ["user_id = ? AND name ILIKE ? ESCAPE E'\\\\'", user_id, favtag_name.to_escaped_for_sql_like + "%"], :select => "id, cached_post_ids").map {|x| x.cached_pos$
    else
      find(:all, :conditions => ["user_id = ?", user_id], :select => "id, cached_post_ids").map {|x| x.cached_post_ids.split(/,/)}.flatten
    end
  end
 
  def self.find_posts(user_id, favtag_name, limit = 60)
    Post.find(:all, :conditions => ["id in (?)", find_post_ids(user_id, favtag_name, limit)], :order => "id DESC", :limit => limit)
  end
  
  def self.process_all(last_processed_post_id)
    posts = Post.find(:all, :conditions => ["id > ? AND created_at < ?", last_processed_post_id, 12.hours.ago], :order => "id DESC", :select => "id")
    fav_tags = FavoriteTag.find(:all)
    
    fav_tags.each do |fav_tag|
      if fav_tag.user.is_privileged_or_higher?
        posts.each do |post|
          if fav_tag.interested?(post.id)
            fav_tag.add_post!(post.id)
          end
        end
      
        fav_tag.prune!
      end
    end

    if posts.any?
      posts.first.id
    else
      last_processed_post_id
    end
  end
end
