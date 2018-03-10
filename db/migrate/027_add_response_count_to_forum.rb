class AddResponseCountToForum < ActiveRecord::Migration[5.1]
  def self.up
    execute "ALTER TABLE forum_posts ADD COLUMN response_count INTEGER NOT NULL DEFAULT 0"
  end

  def self.down
    execute "ALTER TABLE forum_posts DROP COLUMN response_count"
  end
end
