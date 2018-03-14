class FlaggedPostsCreate < ActiveRecord::Migration[5.1]
  def self.up
    execute <<-EOS
      create table flagged_posts (
        id serial primary key,
        created_at timestamp not null default now(),
        post_id integer not null references posts on delete cascade,
        reason text not null
      )
    EOS

    execute "alter table posts drop column is_flagged"
  end

  def self.down
    execute "alter table posts add column is_flagged boolean not null default false"
    execute "drop table flagged_posts"
  end
end
