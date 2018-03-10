class AddPeriodicMaintenanceToJobTasks < ActiveRecord::Migration[5.1]
  def self.up
    JobTask.create(:task_type => "periodic_maintenance", :status => "pending", :repeat_count => -1)
  end

  def self.down
    JobTask.destroy_all(["task_type = 'periodic_maintenance'"])
  end
end
