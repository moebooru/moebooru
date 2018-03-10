class FlaggedPostsAddUserId < ActiveRecord::Migration[5.1]
  def self.up
    execute "alter table flagged_posts add column user_id integer references users on delete cascade"
    execute "alter table flagged_posts add column is_resolved boolean not null default false"
    execute "update flagged_posts set is_resolved = false"
  end

  def self.down
    execute "alter table flagged_posts drop column user_id"
    execute "alter table flagged_posts drop column is_resolved"
  end
end
