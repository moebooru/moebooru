class CreatePostChangeSeq < ActiveRecord::Migration
  def self.up
    execute "CREATE SEQUENCE post_change_seq INCREMENT BY 1 CACHE 10;"
    execute "ALTER TABLE posts ADD COLUMN change_seq INTEGER DEFAULT nextval('post_change_seq'::regclass) NOT NULL;"
    execute "ALTER SEQUENCE post_change_seq OWNED BY posts.change_seq"
    add_index :posts, :change_seq
  end

  def self.down
    remove_index :posts, :change_seq
    execute "ALTER TABLE posts DROP COLUMN change_seq;"
  end
end

