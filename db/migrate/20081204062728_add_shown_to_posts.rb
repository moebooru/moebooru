class AddShownToPosts < ActiveRecord::Migration[5.1]
  def self.up
    execute "ALTER TABLE posts ADD COLUMN is_shown_in_index BOOLEAN NOT NULL DEFAULT TRUE"
    ActiveRecord::Base.update_versioned_tables Post, :attrs => [:is_shown_in_index]
  end

  def self.down
    execute "ALTER TABLE posts DROP COLUMN is_shown_in_index"
    execute "DELETE FROM history_changes WHERE table_name = 'posts' AND field = 'is_shown_in_index'"
  end
end
