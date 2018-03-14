class AddRandomToPosts < ActiveRecord::Migration[5.1]
  def self.up
    execute "ALTER TABLE posts ADD COLUMN random REAL DEFAULT RANDOM() NOT NULL;"
    add_index :posts, :random
  end

  def self.down
    execute "ALTER TABLE posts DROP COLUMN random;"
  end
end
