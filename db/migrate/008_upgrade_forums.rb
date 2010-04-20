class UpgradeForums < ActiveRecord::Migration
	def self.up
		execute "ALTER TABLE forum_posts ADD COLUMN reply_count INTEGER NOT NULL DEFAULT 0"
		execute "ALTER TABLE forum_posts ADD COLUMN last_updated_by INTEGER REFERENCES users ON DELETE SET NULL"
		execute "ALTER TABLE forum_posts ADD COLUMN is_sticky BOOLEAN NOT NULL DEFAULT FALSE"
        execute "ALTER TABLE users ADD COLUMN last_seen_forum_post_id INTEGER REFERENCES forum_posts ON DELETE SET NULL"
	end

	def self.down
		execute "ALTER TABLE forum_posts DROP COLUMN reply_count"
		execute "ALTER TABLE forum_posts DROP COLUMN last_updated_by"
		execute "ALTER TABLE forum_posts DROP COLUMN is_sticky"
		execute "ALTER TABLE users DROP COLUMN last_seen_forum_post_id"
	end
end
