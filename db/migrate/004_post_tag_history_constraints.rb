class PostTagHistoryConstraints < ActiveRecord::Migration
  def self.up
    execute("UPDATE post_tag_histories SET created_at = now() WHERE created_at IS NULL")
    execute("UPDATE post_tag_histories SET ip_addr = '' WHERE ip_addr IS NULL")
    execute("ALTER TABLE post_tag_histories ALTER COLUMN created_at SET NOT NULL")
    execute("ALTER TABLE post_tag_histories ALTER COLUMN ip_addr SET NOT NULL")
  end

  def self.down
    execute("ALTER TABLE post_tag_histories ALTER COLUMN created_at DROP NOT NULL")
    execute("ALTER TABLE post_tag_histories ALTER COLUMN ip_addr DROP NOT NULL")
  end
end
