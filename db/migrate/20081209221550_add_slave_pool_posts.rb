require "pool_post"

class AddSlavePoolPosts < ActiveRecord::Migration[5.1]
  def self.up
    execute "ALTER TABLE pools_posts ADD COLUMN master_id INTEGER REFERENCES pools_posts ON DELETE SET NULL"
    execute "ALTER TABLE pools_posts ADD COLUMN slave_id INTEGER REFERENCES pools_posts ON DELETE SET NULL"

    PoolPost.find(:all).each do |pp|
      pp.need_slave_update = true
      pp.copy_changes_to_slave
    end

    # execute "CREATE INDEX idx_pools_posts_child_id on pools_posts (child_id) WHERE child_id IS NOT NULL"
  end

  def self.down
    execute "DELETE FROM pools_posts WHERE master_id IS NOT NULL"
    execute "ALTER TABLE pools_posts DROP COLUMN master_id"
    execute "ALTER TABLE pools_posts DROP COLUMN slave_id"
  end
end
