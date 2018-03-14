class UsersUpdateLevel < ActiveRecord::Migration[5.1]
  def self.up
    execute "update users set level = 3 where level = 2"
  end

  def self.down
  end
end
