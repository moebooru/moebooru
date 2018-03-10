class AddFileSizeToPosts < ActiveRecord::Migration[5.1]
  def self.up
    execute "ALTER TABLE posts ADD COLUMN file_size INTEGER NOT NULL DEFAULT 0"
    execute "ALTER TABLE posts ADD COLUMN sample_size INTEGER NOT NULL DEFAULT 0"

    p "Updating file sizes..."
    Post.find(:all, :order => "ID ASC").each do |post|
      update = []
      update << "file_size=#{File.size(post.file_path) rescue 0}"
      if post.has_sample?
        update << "sample_size=#{File.size(post.sample_path) rescue 0}"
      end
      execute "UPDATE posts SET #{update.join(",")} WHERE id=#{post.id}"
    end
  end

  def self.down
    execute "ALTER TABLE posts DROP COLUMN file_size"
    execute "ALTER TABLE posts DROP COLUMN sample_size"
  end
end
