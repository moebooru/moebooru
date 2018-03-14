class PoolSequenceAsString < ActiveRecord::Migration[5.1]
  def self.up
    execute "ALTER TABLE pools_posts ALTER COLUMN sequence TYPE TEXT"
    execute "CREATE INDEX idx_pools_posts__sequence_nat ON pools_posts (nat_sort(sequence))"
  end

  def self.down
    execute "DROP INDEX idx_pools_posts__sequence_nat"
    execute "ALTER TABLE pools_posts ALTER COLUMN sequence TYPE INTEGER USING sequence::integer"
  end
end
