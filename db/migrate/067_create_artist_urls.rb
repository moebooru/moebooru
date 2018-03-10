class Artist < ActiveRecord::Base
end

class CreateArtistUrls < ActiveRecord::Migration[5.1]
  def self.up
    create_table :artist_urls do |t|
      t.column :artist_id, :integer, :null => false
      t.column :url, :text, :null => false
      t.column :normalized_url, :text, :null => false
    end

    add_index :artist_urls, :artist_id
    add_index :artist_urls, :url
    add_index :artist_urls, :normalized_url

    add_foreign_key :artist_urls, :artist_id, :artists, :id

    Artist.find(:all, :order => "id").each do |artist|
      [:url_a, :url_b, :url_c].each do |field|
        unless artist[field].blank?
          ArtistUrl.create(:artist_id => artist.id, :url => artist[field])
        end
      end
    end

    remove_column :artists, :url_a
    remove_column :artists, :url_b
    remove_column :artists, :url_c
  end

  def self.down
    drop_table :artist_urls
  end
end
