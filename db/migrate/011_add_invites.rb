class AddInvites < ActiveRecord::Migration[5.1]
  def self.up
    execute "ALTER TABLE users ADD COLUMN invite_count INTEGER NOT NULL DEFAULT 0"
    execute <<-EOS
      CREATE TABLE invites (
        id SERIAL PRIMARY KEY,
        user_id INTEGER NOT NULL REFERENCES users ON DELETE CASCADE,
        activation_key TEXT NOT NULL,
        invite_email TEXT NOT NULL
      )
    EOS
  end

  def self.down
    execute "ALTER TABLE users DROP COLUMN invite_count"
    execute "DROP TABLE invites"
  end
end
