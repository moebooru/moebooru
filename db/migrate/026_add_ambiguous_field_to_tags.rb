class AddAmbiguousFieldToTags < ActiveRecord::Migration
	def self.up
		execute "alter table tags add column is_ambiguous boolean not null default false"
		execute "update tags set is_ambiguous = true where tag_type = 2"
		execute "update tags set tag_type = 0 where tag_type = 2"
	end

	def self.down
	end
end
