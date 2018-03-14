class FixBatchUploadsCreatedAtDefault < ActiveRecord::Migration[5.1]
  def up
    execute "ALTER TABLE batch_uploads ALTER COLUMN created_at SET DEFAULT CURRENT_TIMESTAMP"
  end

  def down
    execute "ALTER TABLE batch_uploads ALTER COLUMN created_at SET DEFAULT CURRENT_TIMESTAMP '2010-08-31 04:17:31.209032'"
  end
end
