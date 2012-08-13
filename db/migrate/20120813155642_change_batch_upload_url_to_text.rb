class ChangeBatchUploadUrlToText < ActiveRecord::Migration
  def change
    change_column :batch_uploads, :url, :text
  end
end
