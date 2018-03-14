class ConvertJobTasksDataDataTypeToJsonb < ActiveRecord::Migration[5.1]
  def up
    execute <<-SQL
      ALTER TABLE job_tasks RENAME data_as_json TO data;
      ALTER TABLE job_tasks ALTER data DROP NOT NULL;
      ALTER TABLE job_tasks ALTER data SET DEFAULT NULL;
      ALTER TABLE job_tasks ALTER data TYPE jsonb USING data::jsonb;
    SQL
  end

  def down
    execute <<-SQL
      ALTER TABLE job_tasks ALTER data TYPE text USING data::text;
      ALTER TABLE job_tasks ALTER data SET DEFAULT '{}';
      ALTER TABLE job_tasks ALTER data SET NOT NULL;
      ALTER TABLE job_tasks RENAME data TO data_as_json;
    SQL
  end
end
