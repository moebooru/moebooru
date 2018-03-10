class AddUserIdToAliasesAndImplicatons < ActiveRecord::Migration[5.1]
  def self.up
    add_column "tag_aliases", "creator_id", :integer
    add_column "tag_implications", "creator_id", :integer
    add_foreign_key "tag_aliases", "creator_id", "users", "id", :on_delete => :cascade
    add_foreign_key "tag_implications", "creator_id", "users", "id", :on_delete => :cascade
  end

  def self.down
    remove_column "tag_aliases", "creator_id"
    remove_column "tag_implications", "creator_id"
  end
end
