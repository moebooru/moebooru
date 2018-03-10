class AddLastCommentReadAtToUser < ActiveRecord::Migration[5.1]
  def self.up
    execute "alter table users add column last_comment_read_at timestamp not null default '1960-01-01'"
  end

  def self.down
    remove_column :forum_posts, :is_locked
  end
end
