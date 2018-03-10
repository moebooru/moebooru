class AddDimensionsIndexOnPosts < ActiveRecord::Migration[5.1]
  def self.up
    add_index "posts", "width"
    add_index "posts", "height"
    execute "CREATE INDEX posts_mpixels ON posts ((width*height/1000000.0))"
  end

  def self.down
    remove_index "posts", "width"
    remove_index "posts", "height"
    execute "DROP INDEX posts_mpixels"
  end
end
