class ForumAddIsLocked < ActiveRecord::Migration
  def self.up
    transaction do
      add_column :forum_posts, :is_locked, :boolean, :null => false, :default => false
      execute "alter table users add column last_forum_topic_read_at timestamp not null default '1960-01-01'"
      drop_table :forum_posts_user_views
      add_index :forum_posts, :updated_at
    end
  end

  def self.down
    transaction do
      remove_column :forum_posts, :is_locked
      remove_column :users, :last_forum_topic_read_at
      remove_index :forum_posts, :updated_at
      execute <<-EOS
  			CREATE TABLE forum_posts_user_views (
  			  id serial primary key,
  				forum_post_id INTEGER NOT NULL REFERENCES forum_posts ON DELETE CASCADE,
  				user_id INTEGER NOT NULL REFERENCES users ON DELETE CASCADE,
  				last_viewed_at TIMESTAMP NOT NULL
  			)
  		EOS

  		execute "CREATE INDEX forum_posts_user_views__forum_post_id__idx ON forum_posts_user_views (forum_post_id)"
  		execute "CREATE INDEX forum_posts_user_views__user_id__idx ON forum_posts_user_views (user_id)"
  		execute "ALTER TABLE forum_posts_user_views ADD CONSTRAINT forum_posts_user_views__unique_forum_post_id_user_id UNIQUE (forum_post_id, user_id)"
  	end
  end
end
