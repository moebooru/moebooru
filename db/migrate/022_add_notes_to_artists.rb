class AddNotesToArtists < ActiveRecord::Migration
	def self.up
		execute "alter table artists add column notes text not null default ''"
	end

	def self.down
		execute "alter table artists drop column notes"
	end
end
