class DropLastSeenForumPostDateFromUsers < ActiveRecord::Migration
	def self.up
		execute "ALTER TABLE users DROP COLUMN last_seen_forum_post_date"
	end

	def self.down
		execute "ALTER TABLE users ADD COLUMN last_seen_forum_post_date TIMESTAMP NOT NULL DEFAULT now()"
	end
end
