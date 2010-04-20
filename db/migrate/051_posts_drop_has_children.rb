class PostsDropHasChildren < ActiveRecord::Migration
  def self.up
    #execute "alter table posts drop column has_children"
  end

  def self.down
    #execute "alter table posts add column has_children boolean not null default false"
  end
end
