class DropExtraIndexesOnArtists < ActiveRecord::Migration
	def self.up
		execute "DROP INDEX idx_artists__image_url"
		execute "DROP INDEX idx_favorites__post_user"
	end

	def self.down
		execute "CREATE INDEX idx_artists__image_url ON artists (url_b)"
		execute "CREATE INDEX idx_favorites__post_user ON favorites (post_id, user_id)"
	end
end
