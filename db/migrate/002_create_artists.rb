class CreateArtists < ActiveRecord::Migration
  def self.up
    execute(<<-EOS)
     CREATE TABLE artists (
       id SERIAL,
       japanese_name TEXT,
       personal_name TEXT,
       handle_name TEXT,
       circle_name TEXT,
       site_name TEXT,
       site_url TEXT,
       image_url TEXT
     )
    EOS
    execute("CREATE INDEX idx_artists__image_url ON artists (image_url)")
    execute("CREATE INDEX idx_artists__personal_name ON artists (personal_name) WHERE personal_name IS NOT NULL")
    execute("CREATE INDEX idx_artists__handle_name ON artists (handle_name) WHERE handle_name IS NOT NULL")
  end

  def self.down
    execute("DROP TABLE artists")
  end
end
