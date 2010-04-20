class ExtendPostTagHistories < ActiveRecord::Migration
  def self.up
    execute "ALTER TABLE post_tag_histories ADD COLUMN user_id INTEGER REFERENCES users ON DELETE SET NULL"
    execute "ALTER TABLE post_tag_histories ADD COLUMN ip_addr TEXT"
    execute "ALTER TABLE post_tag_histories ADD COLUMN created_at TIMESTAMP NOT NULL DEFAULT now()"
  end

  def self.down
    execute "ALTER TABLE post_tag_histories DROP COLUMN user_id"
    execute "ALTER TABLE post_tag_histories DROP COLUMN ip_addr"
    execute "ALTER TABLE post_tag_histories DROP COLUMN created_at"
  end
end
