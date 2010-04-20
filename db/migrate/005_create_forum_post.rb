class CreateForumPost < ActiveRecord::Migration
	def self.up
		execute(<<-EOS)
			CREATE TABLE forum_posts (
				id SERIAL PRIMARY KEY,
				created_at TIMESTAMP NOT NULL,
				updated_at TIMESTAMP NOT NULL,
				title TEXT NOT NULL,
				body TEXT NOT NULL,
				creator_id INTEGER NOT NULL REFERENCES users ON DELETE CASCADE,
				parent_id INTEGER REFERENCES forum_posts ON DELETE CASCADE
			)
		EOS
	end

	def self.down
		execute("DROP TABLE forum_posts")
	end
end
