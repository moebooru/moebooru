class FlagDetailOptionalUserId < ActiveRecord::Migration[5.1]
  def self.up
    # If user_id on a flag is NULL, the flag was performed by the system and not a user.
    execute "ALTER TABLE flagged_post_details ALTER COLUMN user_id DROP NOT NULL"
  end

  def self.down
    execute "ALTER TABLE flagged_post_details ALTER COLUMN user_id SET NOT NULL"
  end
end
