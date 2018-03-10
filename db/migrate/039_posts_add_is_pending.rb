class PostsAddIsPending < ActiveRecord::Migration[5.1]
  def self.up
    execute "alter table posts add column is_pending boolean not null default false"
  end

  def self.down
    execute "alter table posts drop column is_pending"
  end
end
