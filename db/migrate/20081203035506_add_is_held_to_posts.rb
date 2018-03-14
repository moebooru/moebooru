class AddIsHeldToPosts < ActiveRecord::Migration[5.1]
  def self.up
    execute "ALTER TABLE posts ADD COLUMN is_held BOOLEAN NOT NULL DEFAULT FALSE"
    execute "ALTER TABLE posts ADD COLUMN index_timestamp TIMESTAMP NOT NULL DEFAULT now()"
    execute "UPDATE posts SET index_timestamp = created_at"
    add_index :posts, :is_held
  end

  def self.down
    execute "ALTER TABLE posts DROP COLUMN is_held"
    execute "ALTER TABLE posts DROP COLUMN index_timestamp"
  end
end
