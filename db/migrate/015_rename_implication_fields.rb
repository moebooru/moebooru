class RenameImplicationFields < ActiveRecord::Migration
	def self.up
		execute "ALTER TABLE tag_implications RENAME COLUMN parent_id TO consequent_id"
		execute "ALTER TABLE tag_implications RENAME COLUMN child_id TO predicate_id"
	end

	def self.down
		execute "ALTER TABLE tag_implications RENAME COLUMN consequent_id TO parent_id"
		execute "ALTER TABLE tag_implications RENAME COLUMN predicate_id TO child_id"
	end
end
