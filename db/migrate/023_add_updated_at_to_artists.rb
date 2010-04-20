class AddUpdatedAtToArtists < ActiveRecord::Migration
	def self.up
		execute "ALTER TABLE artists ADD COLUMN updated_at TIMESTAMP NOT NULL DEFAULT now()"
	end

	def self.down
		execute "ALTER TABLE artists DROP COLUMN updated_at"
	end
end
