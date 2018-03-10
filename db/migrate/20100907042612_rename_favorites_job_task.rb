class RenameFavoritesJobTask < ActiveRecord::Migration[5.1]
  def self.up
    execute "UPDATE job_tasks SET task_type='calculate_tag_subscriptions' WHERE task_type='calculate_favorite_tags'"
  end

  def self.down
    execute "UPDATE job_tasks SET task_type='calculate_favorite_tags' WHERE task_type='calculate_tag_subscriptions'"
  end
end
