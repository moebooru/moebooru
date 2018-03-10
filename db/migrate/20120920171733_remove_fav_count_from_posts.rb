class RemoveFavCountFromPosts < ActiveRecord::Migration[5.1]
  def up
    remove_column :posts, :fav_count
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
