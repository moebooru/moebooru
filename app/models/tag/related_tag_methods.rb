module TagRelatedTagMethods
  module ClassMethods
    def calculate_related_by_type(tag, type, limit = 25)
      if CONFIG["enable_caching"] && tag.size < 230
        results = Rails.cache.read("reltagsbytype/#{type}/#{Tag.cache_key_enc(tag)}")
        
        if results
          return JSON.parse(results)
        end
      end
      
      sql = <<-EOS
        SELECT (SELECT name FROM tags WHERE id = pt0.tag_id) AS name,
        COUNT(pt0.tag_id) AS post_count
        FROM posts_tags pt0, posts_tags pt1
        WHERE pt0.post_id = pt1.post_id
        AND (SELECT TRUE FROM POSTS p0 WHERE p0.id = pt0.post_id AND p0.status <> 'deleted')
        AND pt1.tag_id = (SELECT id FROM tags WHERE name = ?)
        AND pt0.tag_id IN (SELECT id FROM tags WHERE tag_type = ?)
        GROUP BY pt0.tag_id
        ORDER BY post_count DESC
        LIMIT ?
      EOS

      begin
        results = select_all_sql(sql, tag, type, limit)
      rescue Exception
        results = []
      end
      
      if CONFIG["enable_caching"] && tag.size < 230
        post_count = (Tag.find_by_name(tag).post_count rescue 0) / 3
        post_count = 12 if post_count < 12
        post_count = 200 if post_count > 200
        
        Rails.cache.write("reltagsbytype/#{type}/#{Tag.cache_key_enc(tag)}", results.map {|x| {"name" => x["name"], "post_count" => x["post_count"]}}.to_json, :expires_in => post_count.hours)
      end
      
      return results
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

