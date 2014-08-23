class AddUpdaterIdToArtists < ActiveRecord::Migration
	 def self.up
 		 execute "ALTER TABLE artists ADD COLUMN updater_id INTEGER REFERENCES users ON DELETE SET NULL"
 	end

	 def self.down
 		 execute "ALTER TABLE artists DROP COLUMN updater_id"
 	end
end
