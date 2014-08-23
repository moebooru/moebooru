class AddRatingToTagHistory < ActiveRecord::Migration
  def self.up
    #    execute "ALTER TABLE post_tag_histories ADD COLUMN rating CHARACTER"
  end

  def self.down
    #    remove_column :post_tag_histories, :rating
  end
end
