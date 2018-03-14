class RemovePixivField < ActiveRecord::Migration[5.1]
  def self.up
    remove_column :artists, :pixiv_id
  end

  def self.down
    add_column :artists, :pixiv_id, :integer
  end
end
