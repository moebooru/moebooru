class RemoveFavCountFromPosts < ActiveRecord::Migration
  def up
    remove_column :posts, :fav_count
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
