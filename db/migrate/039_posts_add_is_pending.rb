class PostsAddIsPending < ActiveRecord::Migration
  def self.up
    execute "alter table posts add column is_pending boolean not null default false"
  end

  def self.down
    execute "alter table posts drop column is_pending"
  end
end
