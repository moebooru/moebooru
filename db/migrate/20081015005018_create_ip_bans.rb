class CreateIpBans < ActiveRecord::Migration[5.1]
  def self.up
    execute <<-EOS
      CREATE TABLE ip_bans (
        id SERIAL PRIMARY KEY,
        created_at timestamp NOT NULL DEFAULT now(),
        expires_at timestamp,
        ip_addr inet NOT NULL,
        reason text NOT NULL,
        banned_by integer NOT NULL
      )
    EOS
    add_foreign_key "ip_bans", "banned_by", "users", "id", :on_delete => :cascade
    add_index :ip_bans, :ip_addr
  end

  def self.down
    execute "DROP TABLE ip_bans"
  end
end
