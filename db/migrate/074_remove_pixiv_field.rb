class RemovePixivField < ActiveRecord::Migration
  def self.up
    remove_column :artists, :pixiv_id
  end

  def self.down
    add_column :artists, :pixiv_id, :integer
  end
end
