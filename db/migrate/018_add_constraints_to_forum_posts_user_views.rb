class AddConstraintsToForumPostsUserViews < ActiveRecord::Migration
	def self.up
		execute "ALTER TABLE forum_posts_user_views ADD CONSTRAINT forum_posts_user_views__unique_forum_post_id_user_id UNIQUE (forum_post_id, user_id)"
		execute "CREATE INDEX forum_posts__parent_id_idx ON forum_posts (parent_id) WHERE parent_id IS NULL"
	end

	def self.down
		execute "ALTER TABLE forum_posts_user_views DROP CONSTRAINT forum_posts_user_views__unique_forum_post_id_user_id"
		execute "DROP INDEX forum_posts__parent_id_idx"
	end
end
