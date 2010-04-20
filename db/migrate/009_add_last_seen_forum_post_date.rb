class AddLastSeenForumPostDate < ActiveRecord::Migration
	def self.up
		execute "ALTER TABLE users DROP COLUMN last_seen_forum_post_id"
		execute "ALTER TABLE users ADD COLUMN last_seen_forum_post_date TIMESTAMP NOT NULL DEFAULT now()"
	end

	def self.down
		execute "ALTER TABLE users ADD COLUMN last_seen_forum_post_id INTEGER REFERENCES users ON DELETE SET NULL"
		execute "ALTER TABLE users DROP COLUMN last_seen_forum_post_date"
	end
end
