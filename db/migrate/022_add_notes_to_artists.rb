class AddNotesToArtists < ActiveRecord::Migration[5.1]
  def self.up
    execute "alter table artists add column notes text not null default ''"
  end

  def self.down
    execute "alter table artists drop column notes"
  end
end
