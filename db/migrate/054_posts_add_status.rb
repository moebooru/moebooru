class PostsAddStatus < ActiveRecord::Migration
  def self.up
    transaction do
      execute "create type post_status as enum ('deleted', 'flagged', 'pending', 'active')"
      execute "alter table posts add column status post_status not null default 'active'"
      execute "update posts set status = 'pending' where is_pending = true"
      execute "alter table posts drop column is_pending"
      execute "update posts set status = 'flagged' where id in (select post_id from flagged_posts)"
      execute "alter table posts add column deletion_reason text not null default ''"
      execute "update posts set deletion_reason = (select reason from flagged_posts where post_id = posts.id) where id in (select post_id from flagged_posts)"
      execute "drop table flagged_posts"
      execute "create index post_status_idx on posts (status) where status < 'active'"
    end
  end

  def self.down
    # I'm lazy
    raise IrreversibleMigration
  end
end
