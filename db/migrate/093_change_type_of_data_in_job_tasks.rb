class ChangeTypeOfDataInJobTasks < ActiveRecord::Migration[5.1]
  def self.up
    remove_column :job_tasks, :data_as_json
    add_column :job_tasks, :data_as_json, :text, :null => false, :default => "{}"
  end

  def self.down
    remove_column :job_tasks, :data_as_json
    add_column :job_tasks, :data_as_json, :string, :null => false, :default => "{}"
  end
end
