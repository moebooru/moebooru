class ForumPostsFixCreatorId < ActiveRecord::Migration
  def self.up
    execute "alter table forum_posts drop constraint forum_posts_creator_id_fkey"
    execute "alter table forum_posts alter column creator_id drop not null"
    execute "alter table forum_posts add foreign key (creator_id) references users on delete set null"
  end

  def self.down
  end
end
