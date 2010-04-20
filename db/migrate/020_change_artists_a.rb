class ChangeArtistsA < ActiveRecord::Migration
	def self.up
		execute "ALTER TABLE artists ADD PRIMARY KEY (id)"
		execute "ALTER TABLE artists ADD COLUMN alias_id INTEGER REFERENCES artists ON DELETE SET NULL"
		execute "ALTER TABLE artists ADD COLUMN group_id INTEGER REFERENCES artists ON DELETE SET NULL"
		execute "ALTER TABLE artists RENAME COLUMN site_url TO url_a"
		execute "ALTER TABLE artists RENAME COLUMN image_url TO url_b"
		execute "ALTER TABLE artists ADD COLUMN url_c TEXT"
		execute "ALTER TABLE artists ADD COLUMN name TEXT NOT NULL DEFAULT ''"
		execute "ALTER TABLE artists ALTER COLUMN name DROP DEFAULT"
	end

	def self.down
		raise ActiveRecord::IrreversibleMigration.new
	end
end
