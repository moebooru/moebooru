module TagRelatedTagMethods
  module ClassMethods
    # Returns tags (with type specified by input) related by input tag
    # In array of hashes.
    # Hash in format { 'name' => tag_name, 'post_count' => tag_post_count }
    def calculate_related_by_type(tag, type, limit = 25)
      Rails.cache.fetch({ :category => :reltags_by_type, :type => type, :tag => tag }, :expires_in => 1.hour) do
        Tag.joins(:_posts).where(:posts => { :id => Post.available.has_tag(tag).select('posts.id') }, :tag_type => type).group(:name).count(:all, :order => 'count_all DESC', :limit => limit).reduce([]) do
          |result, hash| result << { 'name' => hash[0], 'post_count' => hash[1] }
        end
      end
    end

    def calculate_related(tags, limit = 25)
      tags = Array(tags)
      return [] if tags.empty?
      Rails.cache.fetch({ :category => :reltags, :tags => tags }, :expires_in => 1.hour) do
        Tag.joins(:_posts).where(:posts => { :id => Post.available.has_tags(tags, :only_ids => true) }).group(:name).count(:all, :order => 'count_all DESC', :limit => limit).reduce([]) do
          |result, hash| result << [hash[0], hash[1]]
        end
      end
    end

    def find_related(tags)
      if tags.is_a?(Array)
        if tags.size == 1
          # Replace tags array into its first element
          # to be searched again later below.
          tags = tags.first
        else
          return calculate_related(tags)
        end
      end
      if tags.to_s != ""
        t = find_by_name(tags.to_s)
        if t
          return t.related
        end
      end

      return []
    end
  end

  def self.included(m)
    m.extend(ClassMethods)
  end

  def related
    if Time.now > cached_related_expires_on
      length = post_count / 3
      length = 12 if length < 12
      length = 8760 if length > 8760

      execute_sql("UPDATE tags SET cached_related = ?, cached_related_expires_on = ? WHERE id = ?", self.class.calculate_related(name).flatten.join(","), length.hours.from_now, id)
      reload
    end

    return cached_related.split(/,/).in_groups_of(2)
  end
end

