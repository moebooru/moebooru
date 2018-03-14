class RemoveSlavePoolPosts < ActiveRecord::Migration[5.1]
  def self.up
    execute "ALTER TABLE pools_posts DROP COLUMN master_id"
    execute "ALTER TABLE pools_posts DROP COLUMN slave_id"
  end

  def self.down
    execute "ALTER TABLE pools_posts ADD COLUMN master_id INTEGER REFERENCES pools_posts ON DELETE SET NULL"
    execute "ALTER TABLE pools_posts ADD COLUMN slave_id INTEGER REFERENCES pools_posts ON DELETE SET NULL"
  end
end
