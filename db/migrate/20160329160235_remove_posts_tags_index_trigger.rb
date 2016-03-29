class RemovePostsTagsIndexTrigger < ActiveRecord::Migration
  def up
    execute <<-SQL.strip_heredoc
      DROP TRIGGER trg_posts_tags_index_update ON posts;
    SQL
  end
end
