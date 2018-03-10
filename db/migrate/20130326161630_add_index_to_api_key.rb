class AddIndexToApiKey < ActiveRecord::Migration[5.1]
  def change
    add_index :users, :api_key, :unique => true
  end
end
