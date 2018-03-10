class AddInlineImages < ActiveRecord::Migration[5.1]
  def self.up
    execute <<-EOS
      CREATE TABLE inlines (
        id SERIAL PRIMARY KEY,
        user_id integer REFERENCES users ON DELETE SET NULL,
        created_at timestamp NOT NULL DEFAULT now(),
        description text NOT NULL DEFAULT ''
      )
    EOS
    execute <<-EOS
      CREATE TABLE inline_images (
        id SERIAL PRIMARY KEY,
        inline_id integer NOT NULL REFERENCES inlines ON DELETE CASCADE,
        md5 text NOT NULL,
        file_ext text NOT NULL,
        description text NOT NULL DEFAULT '',
        sequence INTEGER NOT NULL,
        width INTEGER NOT NULL,
        height INTEGER NOT NULL,
        sample_width INTEGER,
        sample_height INTEGER
      )
    EOS

    add_index :inline_images, :inline_id
  end

  def self.down
    drop_table :inlines
    drop_table :inline_images
  end
end
