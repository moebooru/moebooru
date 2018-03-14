class AddJpegColumns < ActiveRecord::Migration[5.1]
  def self.up
    add_column :posts, :jpeg_width, :integer
    add_column :posts, :jpeg_height, :integer
    add_column :posts, :jpeg_size, :integer, :default => 0, :null => false
    add_column :posts, :jpeg_crc32, :bigint
  end

  def self.down
    remove_column :posts, :jpeg_width
    remove_column :posts, :jpeg_height
    remove_column :posts, :jpeg_size
    remove_column :posts, :jpeg_crc32
  end
end
