class PostsAddIsFlagged < ActiveRecord::Migration[5.1]
  def self.up
    execute "alter table posts add column is_flagged boolean not null default false"
  end

  def self.down
    execute "alter table posts drop column is_flagged"
  end
end
