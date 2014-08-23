class TagImplication < ActiveRecord::Base
  before_create :validate_uniqueness

  def validate_uniqueness
    if self.class.find(:first, :conditions => ["(predicate_id = ? AND consequent_id = ?) OR (predicate_id = ? AND consequent_id = ?)", predicate_id, consequent_id, consequent_id, predicate_id])
      errors.add(:base, "Tag implication already exists")
      return false
    end
  end

  # Destroys the alias and sends a message to the alias's creator.
  def destroy_and_notify(current_user, reason)
    if creator_id && creator_id != current_user.id
      msg = "A tag implication you submitted (#{predicate.name} &rarr; #{consequent.name}) was deleted for the following reason: #{reason}."

      Dmail.create(:from_id => current_user.id, :to_id => creator_id, :title => "One of your tag implications was deleted", :body => msg)
    end

    destroy
  end

  def predicate
    Tag.find(predicate_id)
  end

  def consequent
    Tag.find(consequent_id)
  end

  def predicate=(name)
    t = Tag.find_or_create_by_name(name)
    self.predicate_id = t.id
  end

  def consequent=(name)
    t = Tag.find_or_create_by_name(name)
    self.consequent_id = t.id
  end

  def approve(user_id, ip_addr)
    connection.execute("UPDATE tag_implications SET is_pending = FALSE WHERE id = #{id}")

    t = Tag.find(predicate_id)
    implied_tags = self.class.with_implied(t.name).join(" ")
    Post.available.find(:all, :conditions => ["id IN (SELECT pt.post_id FROM posts_tags pt WHERE pt.tag_id = ?)", t.id]).each do |post|
      post.reload
      post.update_attributes(:tags => post.cached_tags + " " + implied_tags, :updater_user_id => user_id, :updater_ip_addr => ip_addr)
    end
  end

  def self.with_implied(tags)
    return [] if tags.blank?
    all = []
    tags = tags.split if tags.respond_to?(:split) && !tags.is_a?(Array)
    tags = [tags] unless tags.respond_to? :each

    tags.each do |tag|
      all << tag
      results = [tag]

      10.times do
        results = connection.select_values(sanitize_sql_array([<<-SQL, results]))
          SELECT t1.name
          FROM tags t1, tags t2, tag_implications ti
          WHERE ti.predicate_id = t2.id
          AND ti.consequent_id = t1.id
          AND t2.name IN (?)
          AND ti.is_pending = FALSE
        SQL

        if results.any?
          all += results
        else
          break
        end
      end
    end

    all
  end

  def to_xml(options = {})
    { :id => id, :consequent_id => consequent_id, :predicate_id => predicate_id, :pending => is_pending }.to_xml(options.reverse_merge(:root => "tag_implication"))
  end

  def as_json(*args)
    { :id => id, :consequent_id => consequent_id, :predicate_id => predicate_id, :pending => is_pending }.as_json(*args)
  end
end
