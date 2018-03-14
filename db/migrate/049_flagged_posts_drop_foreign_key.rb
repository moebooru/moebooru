class FlaggedPostsDropForeignKey < ActiveRecord::Migration[5.1]
  def self.up
    execute "alter table flagged_posts drop constraint flagged_posts_post_id_fkey"
  end

  def self.down
    execute "alter table flagged_posts add constraint flagged_posts_post_id_fkey foreign key (post_id) references posts (id) on delete cascade"
  end
end
