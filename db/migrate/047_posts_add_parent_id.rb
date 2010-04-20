class PostsAddParentId < ActiveRecord::Migration
  def self.up
    execute "alter table posts add column parent_id integer references posts on delete set null"
    execute "create index idx_posts_parent_id on posts (parent_id) where parent_id is not null"
  end

  def self.down
    execute "alter table posts drop column parent_id"
  end
end
