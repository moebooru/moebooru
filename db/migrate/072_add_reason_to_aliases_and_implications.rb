class AddReasonToAliasesAndImplications < ActiveRecord::Migration[5.1]
  def self.up
    add_column :tag_aliases, :reason, :text, :null => false, :default => ""
    add_column :tag_implications, :reason, :text, :null => false, :default => ""
  end

  def self.down
    remove_column :tag_aliases, :reason
    remove_column :tag_implications, :reason
  end
end
