class ConvertIpTextToInet < ActiveRecord::Migration
  def self.up
    transaction do
      execute "update posts set last_voter_ip = null where last_voter_ip = ''"
      execute "update post_tag_histories set ip_addr = '127.0.0.1' where ip_addr = ''"
      execute "alter table users alter column ip_addr drop default"
      execute "update users set ip_addr = '127.0.0.1' where ip_addr = ''"
      execute "update comments set ip_addr = '127.0.0.1' where ip_addr = 'unknown'"
      execute "alter table posts alter column last_voter_ip type inet using inet(last_voter_ip)"
      execute "alter table posts alter column ip_addr type inet using inet(ip_addr)"
      execute "alter table comments alter column ip_addr type inet using inet(ip_addr)"
      execute "alter table note_versions alter column ip_addr type inet using inet(ip_addr)"
      execute "alter table notes alter column ip_addr type inet using inet(ip_addr)"
      execute "alter table post_tag_histories alter column ip_addr type inet using inet(ip_addr)"
      execute "alter table users alter column ip_addr type inet using inet(ip_addr)"
      execute "alter table wiki_page_versions alter column ip_addr type inet using inet(ip_addr)"
      execute "alter table wiki_pages alter column ip_addr type inet using inet(ip_addr)"
    end
  end

  def self.down
    transaction do
      execute "alter table posts alter column last_voter_ip type text"
      execute "alter table posts alter column ip_addr type text"
      execute "alter table comments alter column ip_addr type text"
      execute "alter table note_versions alter column ip_addr type text"
      execute "alter table notes alter column ip_addr type text"
      execute "alter table post_tag_histories alter column ip_addr type text"
      execute "alter table users alter column ip_addr type text"
      execute "alter table wiki_page_versions alter column ip_addr type text"
      execute "alter table wiki_pages alter column ip_addr type text"
      execute "alter table users alter column ip_addr set default ''"
    end
  end
end
