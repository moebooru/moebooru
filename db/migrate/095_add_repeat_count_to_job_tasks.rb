class AddRepeatCountToJobTasks < ActiveRecord::Migration[5.1]
  def self.up
    add_column :job_tasks, :repeat_count, :integer, :null => false, :default => 0
    JobTask.create(:task_type => "calculate_favorite_tags", :status => "pending", :repeat_count => -1)
  end

  def self.down
    remove_column :job_tasks, :repeat_count
    JobTask.destroy_all(["task_type = 'calculate_favorite_tags'"])
  end
end
