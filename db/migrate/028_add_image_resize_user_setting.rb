class AddImageResizeUserSetting < ActiveRecord::Migration[5.1]
  def self.up
    execute "ALTER TABLE users ADD COLUMN always_resize_images BOOLEAN NOT NULL DEFAULT FALSE"
  end

  def self.down
    execute "ALTER TABLE users DROP COLUMN always_resize_images"
  end
end
