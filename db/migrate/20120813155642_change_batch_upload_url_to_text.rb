class ChangeBatchUploadUrlToText < ActiveRecord::Migration[5.1]
  def change
    change_column :batch_uploads, :url, :text
  end
end
