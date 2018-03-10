class DisableChangeSeqCache < ActiveRecord::Migration[5.1]
  def self.up
    execute "ALTER SEQUENCE post_change_seq CACHE 1"
    execute "ALTER TABLE posts ALTER COLUMN change_seq DROP NOT NULL"
  end

  def self.down
    execute "ALTER SEQUENCE post_change_seq CACHE 10"
    execute "ALTER TABLE posts ALTER COLUMN change_seq SET NOT NULL"
  end
end
