require "translate"
# FIXME: god, why I need this. Anyway, the required helper functions should be
#        moved to library instead. It's not really "view" helper anymore.
include ApplicationHelper

class Comment < ApplicationRecord
  validates_format_of :body, :with => /\S/, :message => "has no content"
  belongs_to :post
  belongs_to :user
  after_save :update_last_commented_at
  after_save :update_fragments
  after_destroy :update_last_commented_at
  attr_accessor :do_not_bump_post

  def self.generate_sql(params)
    Nagato::Builder.new do |_builder, cond|
      cond.add_unless_blank "post_id = ?", params[:post_id].to_i
    end.to_hash
  end

  def self.updated?(user)
    newest_comment = select(:created_at).order("id DESC").first
    newest_comment.created_at > user.last_comment_read_at if newest_comment
  end

  def update_last_commented_at
    # return if self.do_not_bump_post

    comment_count = self.class.where(:post_id => post_id).count
    if comment_count <= CONFIG["comment_threshold"]
      Post.where(:id => post_id).update_all("last_commented_at = (SELECT created_at FROM comments WHERE post_id = #{post_id} ORDER BY created_at DESC LIMIT 1)")
    end
  end

  def get_formatted_body
    format_inlines(format_text(body, :mode => :comment), id)
  end

  def update_fragments
  end

  # Get the comment translated into the requested language.  Languages in source_langs
  # will be left untranslated.
  def get_translated_formatted_body_uncached(_target_lang, _source_langs)
    [get_formatted_body, []]
  end

  def get_translated_formatted_body(target_lang, source_langs)
    source_lang_list = source_langs.join(",")
    key = "comment:" + id.to_s + ":" + updated_at.to_f.to_s + ":" + target_lang + ":" + source_lang_list
    Rails.cache.fetch(key) do
      get_translated_formatted_body_uncached(target_lang, source_langs)
    end
  end

  def author
    User.find_name(user_id)
  end

  def pretty_author
    author.tr("_", " ")
  end

  def author2
    user.name
  rescue
    CONFIG["default_guest_name"]
  end

  def pretty_author2
    author2.tr "_", " "
  end

  def api_attributes
    {
      :id => id,
      :created_at => created_at,
      :post_id => post_id,
      :creator => author,
      :creator_id => user_id,
      :body => body
    }
  end

  def to_xml(options = {})
    api_attributes.to_xml(options.reverse_merge(:root => "comment"))
  end

  def as_json(*args)
    api_attributes.as_json(*args)
  end
end
