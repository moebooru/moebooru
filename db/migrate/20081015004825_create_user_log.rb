class CreateUserLog < ActiveRecord::Migration[5.1]
  def self.up
    execute <<-EOS
          CREATE TABLE user_logs (
            id SERIAL PRIMARY KEY,
            user_id integer NOT NULL REFERENCES users ON DELETE CASCADE,
            created_at timestamp NOT NULL DEFAULT now(),
            ip_addr inet NOT NULL
          )
        EOS

    add_index :user_logs, :user_id
    add_index :user_logs, :created_at
  end

  def self.down
    drop_table :user_logs
  end
end
