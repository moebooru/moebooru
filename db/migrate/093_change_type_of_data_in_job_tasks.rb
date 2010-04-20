class ChangeTypeOfDataInJobTasks < ActiveRecord::Migration
  def self.up
    remove_column :job_tasks, :data_as_json
    add_column :job_tasks, :data_as_json, :text, :null => false, :default => "{}"
  end

  def self.down
    remove_column :job_tasks, :data_as_json
    add_column :job_tasks, :data_as_json, :string, :null => false, :default => "{}"    
  end
end
