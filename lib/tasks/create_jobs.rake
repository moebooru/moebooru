desc "create jobs missing from migrations"
task :create_jobs => :environment do
JobTask.create!(:task_type => "calculate_tag_subscriptions", :status => "pending", :repeat_count => -1)
JobTask.create!(:task_type => "upload_posts_to_mirrors", :status => "pending", :repeat_count => -1)
JobTask.create!(:task_type => "periodic_maintenance", :status => "pending", :repeat_count => -1)
JobTask.create!(:task_type => "upload_batch_posts", :status => "pending", :repeat_count => -1)
JobTask.create!(:task_type => "update_post_frames", :status => "pending", :repeat_count => -1)
end
