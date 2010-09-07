class AddAuxToHistory < ActiveRecord::Migration
  def self.up
    add_column :histories, :aux_as_json, :text
  end

  def self.down
    remove_column :histories, :aux_as_json
  end
end
