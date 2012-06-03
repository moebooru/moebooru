module TagRelatedTagMethods
  module ClassMethods
    # Returns tags (with type specified by input) related by input tag
    # In array of hashes.
    # Hash in format { 'name' => tag_name, 'post_count' => tag_post_count }
    def calculate_related_by_type(tag, type, limit = 25)
      Rails.cache.fetch({ :category => :reltags_by_type, :type => type, :tag => tag }, :expires_in => 1.hour) do
        Tag.joins(:posts).where(:posts => { :id => Post.has_tag(tag) }, :tag_type => type).group(:name).count(:all, :order => 'count_all DESC', :limit => limit).reduce([]) do
          |result, hash| result << { 'name' => hash[0], 'post_count' => hash[1] }
        end
      end
    end

    def calculate_related(tags)
      tags = Array(tags)
      return [] if tags.empty?

      from = ["posts_tags pt0"]
      cond = ["pt0.post_id = pt1.post_id"]
      sql = ""

      # Ignore deleted posts in pt0, so the count excludes them.
      cond << "(SELECT TRUE FROM POSTS p0 WHERE p0.id = pt0.post_id AND p0.status <> 'deleted')"

      (1..tags.size).each {|i| from << "posts_tags pt#{i}"}
      (2..tags.size).each {|i| cond << "pt1.post_id = pt#{i}.post_id"}
      (1..tags.size).each {|i| cond << "pt#{i}.tag_id = (SELECT id FROM tags WHERE name = ?)"}

      sql << "SELECT (SELECT name FROM tags WHERE id = pt0.tag_id) AS tag, COUNT(pt0.*) AS tag_count"
      sql << " FROM " << from.join(", ")
      sql << " WHERE " << cond.join(" AND ")
      sql << " GROUP BY pt0.tag_id"
      sql << " ORDER BY tag_count DESC LIMIT 25"

      begin
        select_all_sql(sql, *tags).map {|x| [x["tag"], x["tag_count"]]}
      rescue Exception
        []
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

