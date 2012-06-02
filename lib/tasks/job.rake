namespace :job do
  JOB_DAEMON = "#{Rails.root}/script/daemons/job_task_processor_ctl.rb"
  desc 'Retart the job task processor'
  task :restart => :environment do
    `ruby #{JOB_DAEMON} restart`
  end

  desc 'Start the job task processor'
  task :start => :environment do
    `ruby #{JOB_DAEMON} start`
  end

  desc 'Stop the job task processor'
  task :stop => :environment do
    `ruby #{JOB_DAEMON} stop`
  end
end
