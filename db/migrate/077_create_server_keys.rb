require 'digest/sha1'

class CreateServerKeys < ActiveRecord::Migration
  def self.up
    create_table :server_keys do |t|
      t.column :name, :string, :null => false
      t.column :value, :text
    end
    
    add_index :server_keys, :name, :unique => true

    session_secret_key = CONFIG["session_secret_key"] || Digest::SHA1.hexdigest(rand(10 ** 32))
    user_password_salt = CONFIG["password_salt"] || Digest::SHA1.hexdigest(rand(10 ** 32))
    
    execute "insert into server_keys (name, value) values ('session_secret_key', '#{session_secret_key}')"
    execute "insert into server_keys (name, value) values ('user_password_salt', '#{user_password_salt}')"
  end

  def self.down
    drop_table :server_keys
  end
end
