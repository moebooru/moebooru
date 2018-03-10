class AddForumPostsUserViews < ActiveRecord::Migration[5.1]
  def self.up
    execute <<-EOS
      CREATE TABLE forum_posts_user_views (
        forum_post_id INTEGER NOT NULL REFERENCES forum_posts ON DELETE CASCADE,
        user_id INTEGER NOT NULL REFERENCES users ON DELETE CASCADE,
        last_viewed_at TIMESTAMP NOT NULL
      )
    EOS

    execute "CREATE INDEX forum_posts_user_views__forum_post_id__idx ON forum_posts_user_views (forum_post_id)"
    execute "CREATE INDEX forum_posts_user_views__user_id__idx ON forum_posts_user_views (user_id)"
  end

  def self.down
    execute "DROP TABLE forum_posts_user_views"
  end
end
