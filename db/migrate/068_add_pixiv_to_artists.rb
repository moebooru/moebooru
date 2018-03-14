class AddPixivToArtists < ActiveRecord::Migration[5.1]
  def self.up
    add_column :artists, :pixiv_id, :integer
    add_index :artists, :pixiv_id
  end

  def self.down
    remove_column :artists, :pixiv_id
  end
end
