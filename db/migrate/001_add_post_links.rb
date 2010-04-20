class AddPostLinks < ActiveRecord::Migration
  def self.up
    execute("ALTER TABLE posts ADD COLUMN next_post_id INTEGER REFERENCES posts ON DELETE SET NULL")
    execute("ALTER TABLE posts ADD COLUMN prev_post_id INTEGER REFERENCES posts ON DELETE SET NULL")
    execute("UPDATE posts SET next_post_id = (SELECT _.id FROM posts _ WHERE _.id > posts.id ORDER BY _.id LIMIT 1)")
    execute("UPDATE posts SET prev_post_id = (SELECT _.id FROM posts _ WHERE _.id < posts.id ORDER BY _.id DESC LIMIT 1)")
  end

  def self.down
    execute("ALTER TABLE posts DROP COLUMN next_post_id")
    execute("ALTER TABLE posts DROP COLUMN prev_post_id")
  end
end
