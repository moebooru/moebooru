class AddIndexToApiKey < ActiveRecord::Migration
  def change
    add_index :users, :api_key, unique: true
  end
end
