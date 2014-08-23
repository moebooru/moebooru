module Post::CountMethods
  module ClassMethods
    def fast_count(tags = nil)
      # A small sanitation
      tags = tags.to_s.strip.gsub(/ +/, " ")
      cache_version = Rails.cache.read("$cache_version").to_i
      key = { :post_count => tags, :v => cache_version }

      count = Rails.cache.fetch(key) {
        Post.count_by_sql(Post.generate_sql(tags, :count => true))
      }.to_i

      count

      # This is just too brittle, and hard to make work with other features that may
      # hide posts from the index.
#      if tags.blank?
#        return select_value_sql("SELECT row_count FROM table_data WHERE name = 'posts'").to_i
#      else
#        c = select_value_sql("SELECT post_count FROM tags WHERE name = ?", tags).to_i
#        if c == 0
#          return Post.count_by_sql(Post.generate_sql(tags, :count => true))
#        else
#          return c
#        end
#      end
    end

    def recalculate_row_count
      execute_sql("UPDATE table_data SET row_count = (SELECT COUNT(*) FROM posts WHERE parent_id IS NULL AND status <> 'deleted') WHERE name = 'posts'")
    end
  end

  def self.included(m)
    m.extend(ClassMethods)
    m.after_create :increment_count
    m.set_callback :delete, :after, :decrement_count
    m.set_callback :undelete, :after, :increment_count
  end

  def increment_count
    execute_sql("UPDATE table_data SET row_count = row_count + 1 WHERE name = 'posts'")
  end

  def decrement_count
    execute_sql("UPDATE table_data SET row_count = row_count - 1 WHERE name = 'posts'")
  end
end
