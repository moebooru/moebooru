class AddNameNormalizedToUsers < ActiveRecord::Migration[6.0]
  class User < ActiveRecord::Base
  end

  def up
    change_table :users do |t|
      t.string :name_normalized, limit: 255
      t.index :name_normalized, unique: true
    end

    User.update_all('name_normalized = LOWER(name)')

    change_column :users, :name_normalized, :string, limit: 255, null: false
  end

  def down
    change_table :users do |t|
      t.remove_index :name_normalized
      t.remove :name_normalized
    end
  end
end
