require 'translate'
# FIXME: god, why I need this. Anyway, the required helper functions should be
#        moved to library instead. It's not really "view" helper anymore.
include ApplicationHelper

class Comment < ActiveRecord::Base
  validates_format_of :body, :with => /\S/, :message => 'has no content'
  belongs_to :post
  belongs_to :user
  after_save :update_last_commented_at
  after_save :update_fragments
  after_destroy :update_last_commented_at
  attr_accessor :do_not_bump_post

  def self.generate_sql(params)
    return Nagato::Builder.new do |builder, cond|
      cond.add_unless_blank "post_id = ?", params[:post_id]
    end.to_hash
  end

  def self.updated?(user)
    conds = []
    conds += ["user_id <> %d" % [user.id]] unless user.is_anonymous?

    newest_comment = Comment.find(:first, :order => "id desc", :limit => 1, :select => "created_at", :conditions => conds)
    return false if newest_comment == nil
    return newest_comment.created_at > user.last_comment_read_at
  end

  def update_last_commented_at
    # return if self.do_not_bump_post

    comment_count = connection.select_value("SELECT COUNT(*) FROM comments WHERE post_id = #{post_id}").to_i
    if comment_count <= CONFIG["comment_threshold"]
      connection.execute("UPDATE posts SET last_commented_at = (SELECT created_at FROM comments WHERE post_id = #{post_id} ORDER BY created_at DESC LIMIT 1) WHERE posts.id = #{post_id}")
    end
  end

  def get_formatted_body
    return format_inlines(format_text(self.body, :mode => :comment), self.id)
  end

  def update_fragments
    return
  end

  # Get the comment translated into the requested language.  Languages in source_langs
  # will be left untranslated.
  def get_translated_formatted_body_uncached(target_lang, source_langs)
      return self.get_formatted_body, []
  end

  def get_translated_formatted_body(target_lang, source_langs)
    source_lang_list = source_langs.join(",")
    key = "comment:" + self.id.to_s + ":" + self.updated_at.to_f.to_s + ":" + target_lang + ":" + source_lang_list
    return Rails.cache.fetch(key) {
      get_translated_formatted_body_uncached(target_lang, source_langs)
    }
  end

  def author
    return User.find_name(self.user_id)
  end

  def pretty_author
    author.tr("_", " ")
  end

  def author2
    user.name
  end

  def pretty_author2
    author2.tr '_', ' '
  end

  def api_attributes
    return {
      :id => id,
      :created_at => created_at,
      :post_id => post_id,
      :creator => author,
      :creator_id => user_id,
      :body => body
    }
  end

  def to_xml(options = {})
    return api_attributes.to_xml(options.reverse_merge(:root => "comment"))
  end

  def as_json(*args)
    return api_attributes.as_json(*args)
  end
end
