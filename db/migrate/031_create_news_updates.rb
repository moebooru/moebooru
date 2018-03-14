class CreateNewsUpdates < ActiveRecord::Migration[5.1]
  def self.up
    execute <<-EOS
      CREATE TABLE news_updates (
        id SERIAL PRIMARY KEY,
        created_at TIMESTAMP NOT NULL DEFAULT now(),
        updated_at TIMESTAMP NOT NULL DEFAULT now(),
        user_id INTEGER NOT NULL REFERENCES users ON DELETE CASCADE,
        title TEXT NOT NULL,
        body TEXT NOT NULL
      )
    EOS
  end

  def self.down
    execute "DROP TABLE news_updates"
  end
end
