class AddLastDeletedPostSeenAt < ActiveRecord::Migration[5.1]
  def self.up
    execute "ALTER TABLE users ADD COLUMN last_deleted_post_seen_at timestamp not null default '1960-01-01'"
    add_index :flagged_post_details, :created_at

    # Set all existing users to now, so we don't notify everyone of previous deletions.
    execute "UPDATE users SET last_deleted_post_seen_at=now()"
  end

  def self.down
    remove_column :users, :last_deleted_post_seen_at
    remove_index :flagged_post_details, :created_at
  end
end
