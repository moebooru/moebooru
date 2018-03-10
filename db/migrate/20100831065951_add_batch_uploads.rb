class AddBatchUploads < ActiveRecord::Migration[5.1]
  def self.up
    create_table :batch_uploads do |t|
      t.column :user_id, :integer, :null => false
      t.foreign_key :user_id, :users, :id, :on_delete => :cascade
      t.column :ip, :inet
      t.column :url, :string, :null => false
      t.column :tags, :string, :null => false, :default => ""

      # If we're handling this entry right now.  This is independent from status; this is
      # only informative, to let the user know which file is being processed.
      t.column :active, :boolean, :null => false, :default => false

      # If this entry has failed, and won't be retried automatically:
      # pending, error, finished
      t.column :status, :string, :null => false, :default => "pending"

      t.column :created_at, :timestamp, :null => false, :default => "now()"
      t.column :data_as_json, :string, :null => false, :default => "{}"
    end

    execute "ALTER TABLE batch_uploads ADD UNIQUE (user_id, url)"

    JobTask.create!(:task_type => "upload_batch_posts", :status => "pending", :repeat_count => -1)
  end

  def self.down
    drop_table :batch_uploads
    JobTask.destroy_all(["task_type = 'upload_batch_posts'"])
  end
end
