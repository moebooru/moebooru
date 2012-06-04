module PostTagMethods
  attr_accessor :tags, :new_tags, :old_tags, :old_cached_tags

  module ClassMethods
    def find_by_tags(tags, options = {})
      return find_by_sql(Post.generate_sql(tags, options))
    end

    def recalculate_cached_tags(id = nil)
      conds = []
      cond_params = []

      sql = %{
        UPDATE posts p SET cached_tags = (
          SELECT array_to_string(coalesce(array(
            SELECT t.name
            FROM tags t, posts_tags pt
            WHERE t.id = pt.tag_id AND pt.post_id = p.id
            ORDER BY t.name
          ), '{}'::text[]), ' ')
        )
      }

      if id
        conds << "WHERE p.id = ?"
        cond_params << id
      end

      sql = [sql, conds].join(" ")
      execute_sql sql, *cond_params
    end

    # new, previous and latest are History objects for cached_tags.  Split
    # the tag changes apart.
    def tag_changes(new, previous, latest)
      new_tags = new.value.scan(/\S+/)
      old_tags = (previous.value rescue "").scan(/\S+/)
      latest_tags = latest.value.scan(/\S+/)

      {
        :added_tags => new_tags - old_tags,
        :removed_tags => old_tags - new_tags,
        :unchanged_tags => new_tags & old_tags,
        :obsolete_added_tags => (new_tags - old_tags) - latest_tags,
        :obsolete_removed_tags => (old_tags - new_tags) & latest_tags,
      }
    end
  end

  def self.included(m)
    m.extend ClassMethods
    m.before_save :commit_metatags
    m.after_save :commit_tags
    m.after_save :save_post_history
    m.has_many :tag_history, :class_name => "PostTagHistory", :table_name => "post_tag_histories", :order => "id desc"
    m.versioned :source, :default => ""
    m.versioned :cached_tags
  end

  def cached_tags_undo(change, redo_changes=false)
    current_tags = self.cached_tags.scan(/\S+/)
    prev = change.previous

    change, prev = prev, change if redo_changes
    changes = Post.tag_changes(change, prev, change.latest)
    new_tags = (current_tags - changes[:added_tags]) | changes[:removed_tags]
    self.attributes = {:tags => new_tags.join(" ")}
  end

  def cached_tags_redo(change)
    cached_tags_undo(change, true)
  end

  # === Parameters
  # * :tag<String>:: the tag to search for
  def has_tag?(tag)
    return cached_tags =~ /(^|\s)#{tag}($|\s)/
  end

  # Returns the tags in a URL suitable string
  def tag_title
    return title_tags.gsub(/\W+/, "-")[0, 50]
  end

  # Return the tags we display in URLs, page titles, etc.
  def title_tags
    ret = ""
    ret << cached_tags
    ret
  end

  def tags
    cached_tags
  end

  # Sets the tags for the post. Does not actually save anything to the database when called.
  #
  # === Parameters
  # * :tags<String>:: a whitespace delimited list of tags
  def tags=(tags)
    self.new_tags = Tag.scan_tags(tags)

    current_tags = cached_tags.scan(/\S+/)
    self.touch_change_seq! if new_tags != current_tags
  end

  # Returns all versioned tags and metatags.
  def cached_tags_versioned
    ["rating:" + self.rating, cached_tags].join(" ")
  end

  # Commit metatags; this is done before save, so any changes are stored normally.
  def commit_metatags
    return if new_tags.nil?

    transaction do
      metatags, self.new_tags = new_tags.partition {|x| x=~ /^(hold|unhold|show|hide|\+flag|source:.*)$/}
      metatags.each do |metatag|
        case metatag
        when /^hold$/
          self.is_held = true

        when /^unhold$/
          self.is_held = false

        when /^show$/
          self.is_shown_in_index = true

        when /^hide$/
          self.is_shown_in_index = false

        when /^\+flag$/
          # Permissions for this are checked on commit.
          self.metatag_flagged = "moderator flagged"
        when /^source:(.*)/
          self.source = $1
        end
      end
    end
  end

  # Commit any tag changes to the database.  This is done after save, so any changes
  # must be made directly to the database.
  def commit_tags
    return if new_tags.nil?

    if old_tags
      # If someone else committed changes to this post before we did,
      # then try to merge the tag changes together.
      current_tags = cached_tags.scan(/\S+/)
      self.old_tags = Tag.scan_tags(old_tags)
      self.new_tags = (current_tags + new_tags) - old_tags + (current_tags & new_tags)
    end

    metatags, self.new_tags = new_tags.partition {|x| x=~ /^((?:-pool|pool|rating|parent|child):|[qse]$)/}

    transaction do
      metatags.each do |metatag|
        if metatag =~ /^([qse])$/
          metatag = "rating:#{$1}"
        end

        case metatag
        when /^pool:(.+)/
          begin
            name, seq = $1.split(":")

            pool = Pool.find_by_name(name)

            # Set :ignore_already_exists, so pool:1:2 can be used to change the sequence number
            # of a post that already exists in the pool.
            options = {:user => User.find(updater_user_id), :ignore_already_exists => true}
            if defined?(seq) then
              options[:sequence] = seq
            end

            if pool.nil? and name !~ /^\d+$/
              pool = Pool.create(:name => name, :is_public => false, :user_id => updater_user_id)
            end

            next if pool.nil?

            next if Thread.current["danbooru-user"] && !pool.can_change?(Thread.current["danbooru-user"], nil)
            pool.add_post(id, options) if pool
          rescue Pool::PostAlreadyExistsError
          rescue Pool::AccessDeniedError
          end


        when /^-pool:(.+)/
          name, cmd = $1.split(":")

          pool = Pool.find_by_name(name)
          next if Thread.current["danbooru-user"] && !pool.can_change?(Thread.current["danbooru-user"], nil)

          if cmd == "parent" then
            # If we have a parent, remove ourself from the pool and add our parent in
            # our place.  If we have no parent, do nothing and leave us in the pool.
            if not self.parent_id.nil?
              pool.transfer_post_to_parent(self.id, self.parent_id)
            end
            next
          end

          pool.remove_post(id) if pool

        when /^rating:([qse])/
          self.rating = $1 # so we don't have to reload for history_tag_string below
          execute_sql("UPDATE posts SET rating = ? WHERE id = ?", $1, id)


        when /^parent:(\d*)/
          self.parent_id = $1

          if CONFIG["enable_parent_posts"] && (Post.exists?(parent_id) or parent_id == 0)
            Post.set_parent(id, parent_id)
          end

        when /^child:(\d*)/
          child_id = $1
          if CONFIG["enable_parent_posts"] && Post.exists?(child_id)
            # Don't just use set_parent, or history won't be saved, since it saves directly
            # to the database.
            p = Post.find(child_id)
            p.parent_id = self.id
            p.save!
          end
        end
      end

      self.new_tags << "tagme" if new_tags.empty?
      self.new_tags = TagAlias.to_aliased(new_tags)
      self.new_tags = TagImplication.with_implied(new_tags).uniq

      # TODO: be more selective in deleting from the join table
      execute_sql("DELETE FROM posts_tags WHERE post_id = ?", id)
      self.new_tags = new_tags.map {|x| Tag.find_or_create_by_name(x)}.uniq

      # If any tags are newly active, expire the tag cache.
      if not self.new_tags.empty? then
        any_new_tags = false
        previous_tags = self.cached_tags.split(" ")
        self.new_tags.each do |tag|
          # If this tag is in old_tags, then it's already active and we just removed it
          # in the above DELETE, so it's not really a newly activated tag.  (This isn't
          # self.old_tags; that's the tags the user saw before he edited, not the data
          # we're replacing.)
          if tag.post_count == 0 and not previous_tags.include?(tag.name) then
            any_new_tags = true
          end
        end

        if any_new_tags then
          Rails.cache.expire_tag_version
        end
      end

      # Tricky: Postgresql's locking won't serialize this DELETE/INSERT, so it's
      # possible for two simultaneous updates to both delete all tags, then insert
      # them, duplicating them all.
      #
      # Work around this by selecting the existing tags within the INSERT and removing
      # any that already exist.  Normally, the inner SELECT will return no rows; if
      # another process inserts rows before our INSERT, it'll return the rows that it
      # inserted and we'll avoid duplicating them.
      tag_set = new_tags.map {|x| ("(#{id}, #{x.id})")}.join(", ")
      #execute_sql("INSERT INTO posts_tags (post_id, tag_id) VALUES " + tag_set)
      sql = <<-EOS
        INSERT INTO posts_tags (post_id, tag_id)
        SELECT t.post_id, t.tag_id
         FROM (VALUES #{tag_set}) AS t(post_id, tag_id)
         WHERE t.tag_id NOT IN (SELECT tag_id FROM posts_tags pt WHERE pt.post_id = #{self.id})
      EOS

      execute_sql(sql)

      Post.recalculate_cached_tags(self.id)

      # Store the old cached_tags, so we can expire them.
      self.old_cached_tags = self.cached_tags
      self.cached_tags = select_value_sql("SELECT cached_tags FROM posts WHERE id = #{id}")

      self.new_tags = nil
    end
  end

  def save_post_history
    new_cached_tags = cached_tags_versioned
    if tag_history.empty? or tag_history.first.tags != new_cached_tags
      PostTagHistory.create(:post_id => id, :tags => new_cached_tags,
                            :user_id => Thread.current["danbooru-user_id"],
                            :ip_addr => Thread.current["danbooru-ip_addr"] || "127.0.0.1")
    end
  end
end
