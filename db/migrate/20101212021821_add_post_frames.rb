class AddPostFrames < ActiveRecord::Migration[5.1]
  def self.up
    create_table :post_frames do |t|
      t.column :post_id, :integer, :null => false
      t.foreign_key :post_id, :posts, :id, :on_delete => :cascade

      t.column :is_target, :boolean, :null => false, :default => false
      t.column :is_active, :boolean, :null => false, :default => false
      t.column :is_created, :boolean, :null => false, :default => false
      t.column :is_warehoused, :boolean, :null => false, :default => false

      t.column :source_width, :integer, :null => false
      t.column :source_height, :integer, :null => false
      t.column :source_top, :integer, :null => false
      t.column :source_left, :integer, :null => false
    end

    add_index :post_frames, :post_id

    execute "ALTER TABLE posts ADD COLUMN frames TEXT DEFAULT '' NOT NULL"
    execute "ALTER TABLE posts ADD COLUMN frames_pending TEXT DEFAULT '' NOT NULL"
    execute "ALTER TABLE posts ADD COLUMN frames_warehoused BOOLEAN DEFAULT false NOT NULL"

    # Allow quicky looking up posts where frames and frames_pending differ.  This
    # excludes posts which have no frames at all, which excludes the vast majority
    # of posts from this index.
    execute "CREATE INDEX post_frames_out_of_date ON posts (id) WHERE (frames <> frames_pending AND (frames <> '' OR frames_pending <> ''))"

    JobTask.create!(:task_type => "update_post_frames", :status => "pending", :repeat_count => -1)
  end

  def self.down
    drop_table :post_frames
    execute "ALTER TABLE posts DROP COLUMN frames"
    execute "ALTER TABLE posts DROP COLUMN frames_pending"
    execute "ALTER TABLE posts DROP COLUMN frames_warehoused"
    JobTask.destroy_all(["task_type = 'update_post_frames'"])
  end
end
