class AddMirrorPostsToJobTasks < ActiveRecord::Migration[5.1]
  def self.up
    JobTask.create(:task_type => "upload_posts_to_mirrors", :status => "pending", :repeat_count => -1)
  end

  def self.down
    JobTask.destroy_all(["task_type = 'upload_posts_to_mirrors'"])
  end
end
