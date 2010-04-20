class CreateJobTasks < ActiveRecord::Migration
  def self.up
    create_table :job_tasks do |t|
      t.column :task_type, :string, :null => false
      t.column :data_as_json, :string, :null => false
      t.column :status, :string, :null => false
      t.column :status_message, :text
      t.timestamps
    end
  end

  def self.down
    drop_table :job_tasks
  end
end
