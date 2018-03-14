class NoteVersionsAddIndexOnUserId < ActiveRecord::Migration[5.1]
  def self.up
    add_index :note_versions, :user_id
  end

  def self.down
    remove_index :note_versions, :user_id
  end
end
