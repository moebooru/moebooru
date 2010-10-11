require 'lib/translate'

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
    # We need to instantiate a template to get access to template helpers.
    template = ActionView::Base.new(CommentController.view_paths)
    template.helpers.send :include, CommentController.master_helper_module

    return template.format_inlines(template.format_text(self.body, :mode => :comment), self.id)
  end

  def update_fragments
    blocks = {}
    DText.split_blocks(self.get_formatted_body, blocks)

    block_data = {}
    blocks.each { |id, block|
      block_data[id] = {
        :source_text => block,
        :translated => {}
      }
    }

    # The API wants a referer for what's being translated.  Give the URL to the comment's
    # post.
    url = CONFIG["url_base"] + '/post/show/' + self.post_id.to_s
    target_languages = CONFIG["translate_languages"]
    return if target_languages.nil?

    blocks.each { |id, block|
      translations, source_lang = Translate.translate(block, :referer => url, :languages => target_languages)
      data = block_data[id]
      translations.each { |lang, text|
        data[:source_lang] = source_lang

        # Mark each block with the language it's translated from, into, and whether they're
        # the same, so CSS rules can use it later.
        cls = "from-lang-" + source_lang
        cls += " to-lang-" + lang
        cls += (source_lang == lang)? " original-language":" translated-language" 
        marked_text = DText.add_html_class(text, cls)

        data[:translated][lang] = marked_text
      }

      if not data[:translated].has_key?(source_lang) then
        data[:translated][source_lang] = block
      end
    }

    transaction do
      execute_sql("DELETE FROM comment_fragments WHERE comment_id=#{self.id}")
      block_data.each { |id, block|
        block[:translated].each { |target_lang, body|
          CommentFragment.create(
            :comment_id => self.id,
            :block_id => id,
            :source_lang => block[:source_lang],
            :target_lang => target_lang,
            :body => body
          )
        }
      }
    end
  end

  # Get the comment translated into the requested language.  Languages in source_langs
  # will be left untranslated.
  def get_translated_formatted_body_uncached(target_lang, source_langs)
    # Grab all relevant comment fragments: ones translated to the user's target language, and
    # ones originally in the user's secondary languages.
    conds = ["target_lang = '#{target_lang}'"]
    source_lang_list = source_langs.map { |l| "'" + l + "'" }.join(",")
    conds << "source_lang IN (#{source_lang_list})" if not source_lang_list.empty?
    conds = conds.join(" OR ")
    fragments = CommentFragment.find(:all, :conditions => ["comment_id = #{self.id} AND (#{conds})"])

    if fragments.empty?
      # We didn't get any parts; this comment isn't translated.  Return the original string.
      return self.get_formatted_body, []
    end

    # We have a list of blocks for all relevant languages.  We need to choose one language for each
    # block ID.
    blocks_by_id = {}
    block_language = {}
    fragments.each { |f|
      blocks_by_id[f.block_id] ||= {}
      blocks_by_id[f.block_id][f.target_lang] = f
      block_language[f.block_id] = f.source_lang
    }

    selected_blocks = {}
    translated_from_languages = []
    blocks_by_id.each { |id, blocks|
      source_lang = block_language[id]
      if blocks.has_key?(target_lang) and not source_langs.include?(source_lang) then
        # We have the user's preferred language, and the fragment isn't in the list of
        # languages to not translate.  Use the translation.
        use_lang = target_lang
      else
        # Use the original text.
        use_lang = source_lang
      end
      selected_blocks[id] = blocks[use_lang].body
      translated_from_languages << use_lang if use_lang != source_lang
    }

    return DText.combine_blocks(selected_blocks), translated_from_languages
  end

  def get_translated_formatted_body(target_lang, source_langs)
    source_lang_list = source_langs.join(",")
    key = "comment:" + self.id.to_s + ":" + self.updated_at.to_f.to_s + ":" + target_lang + ":" + source_lang_list
    return Cache.get(key) {
      get_translated_formatted_body_uncached(target_lang, source_langs)
    }
  end

  def author
    return User.find_name(self.user_id)
  end
  
  def pretty_author
    author.tr("_", " ")
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
    return api_attributes.to_xml(options.merge(:root => "comment"))
  end

  def to_json(*args)
    return api_attributes.to_json(*args)
  end
end
