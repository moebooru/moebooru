class ChangeArtistsB < ActiveRecord::Migration
	def self.up
		execute "ALTER TABLE artists DROP COLUMN japanese_name"
		execute "ALTER TABLE artists DROP COLUMN personal_name"
		execute "ALTER TABLE artists DROP COLUMN handle_name"
		execute "ALTER TABLE artists DROP COLUMN circle_name"
		execute "ALTER TABLE artists DROP COLUMN site_name"
		execute "DELETE FROM artists WHERE name = ''"
		execute "ALTER TABLE artists ADD CONSTRAINT artists_name_uniq UNIQUE (name)"
		execute "CREATE INDEX artists_url_a_idx ON artists (url_a)"
		execute "CREATE INDEX artists_url_b_idx ON artists (url_b) WHERE url_b IS NOT NULL"
		execute "CREATE INDEX artists_url_c_idx ON artists (url_c) WHERE url_c IS NOT NULL"
	end

	def self.down
		raise ActiveRecord::IrreversibleMigration.new
	end
end
