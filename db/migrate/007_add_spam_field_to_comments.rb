class AddSpamFieldToComments < ActiveRecord::Migration[5.1]
  def self.up
    execute("ALTER TABLE comments DROP COLUMN signal_level")
    execute("ALTER TABLE comments ADD COLUMN is_spam BOOLEAN")
  end

  def self.down
    execute("ALTER TABLE comments ADD COLUMN signal_level")
    execute("ALTER TABLE comments DROP COLUMN is_spam BOOLEAN")
  end
end
