class UsersAddIpAddr < ActiveRecord::Migration[5.1]
  def self.up
    execute "alter table users add column ip_addr text not null default ''"
    execute "alter table users add column last_logged_in_at timestamp not null default now()"
  end

  def self.down
    execute "alter table users drop column ip_addr"
    execute "alter table users drop column last_logged_in_at"
  end
end
