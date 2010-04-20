class UsersUpdateLevel < ActiveRecord::Migration
  def self.up
    execute "update users set level = 3 where level = 2"
  end

  def self.down
  end
end
