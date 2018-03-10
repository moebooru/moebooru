class PostSourceNotNull < ActiveRecord::Migration[5.1]
  def self.up
    execute "UPDATE posts SET source='' WHERE source IS NULL"
    execute "UPDATE history_changes SET value='' WHERE table_name='posts' AND field='source' AND value IS NULL"
    execute "ALTER TABLE posts ALTER COLUMN source SET NOT NULL"
  end

  def self.down
    execute "ALTER TABLE posts ALTER COLUMN source DROP NOT NULL"
  end
end
