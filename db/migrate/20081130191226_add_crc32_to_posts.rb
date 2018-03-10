class AddCrc32ToPosts < ActiveRecord::Migration[5.1]
  def self.up
    execute "ALTER TABLE posts ADD COLUMN crc32 BIGINT"
    execute "ALTER TABLE posts ADD COLUMN sample_crc32 BIGINT"
    execute "ALTER TABLE pools ADD COLUMN zip_created_at TIMESTAMP"
    execute "ALTER TABLE pools ADD COLUMN zip_is_warehoused BOOLEAN NOT NULL DEFAULT FALSE"
  end

  def self.down
    execute "ALTER TABLE posts DROP COLUMN crc32"
    execute "ALTER TABLE posts DROP COLUMN sample_crc32"
    execute "ALTER TABLE pools DROP COLUMN zip_created_at"
    execute "ALTER TABLE pools DROP COLUMN zip_is_warehoused"
  end
end
