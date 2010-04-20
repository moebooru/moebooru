class FavoritesAddCreatedAt < ActiveRecord::Migration
  def self.up
    execute "alter table favorites add column created_at timestamp not null default now()"
    execute "update favorites set created_at = (select created_at from posts where id = favorites.post_id)"
  end

  def self.down
    execute "alter table favorites drop column created_at"
  end
end
