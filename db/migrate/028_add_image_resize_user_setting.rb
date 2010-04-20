class AddImageResizeUserSetting < ActiveRecord::Migration
  def self.up
    execute "ALTER TABLE users ADD COLUMN always_resize_images BOOLEAN NOT NULL DEFAULT FALSE"
  end

  def self.down
    execute "ALTER TABLE users DROP COLUMN always_resize_images"
  end
end
