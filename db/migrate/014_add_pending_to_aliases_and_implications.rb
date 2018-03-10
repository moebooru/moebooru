class AddPendingToAliasesAndImplications < ActiveRecord::Migration[5.1]
  def self.up
    execute "ALTER TABLE tag_aliases ADD COLUMN is_pending BOOLEAN NOT NULL DEFAULT FALSE"
    execute "ALTER TABLE tag_implications ADD COLUMN is_pending BOOLEAN NOT NULL DEFAULT FALSE"
  end

  def self.down
    execute "ALTER TABLE tag_aliases DROP COLUMN is_pending"
    execute "ALTER TABLE tag_implications DROP COLUMN is_pending"
  end
end
