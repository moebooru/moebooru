class RenameInviteEmailField < ActiveRecord::Migration
	def self.up
		execute "ALTER TABLE invites RENAME COLUMN invite_email TO email"
	end

	def self.down
		execute "ALTER TABLE invites RENAME COLUMN email TO invite_email"
	end
end
