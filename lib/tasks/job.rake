require "rbconfig"

namespace :job do
  ruby_exec = File.join(RbConfig::CONFIG["bindir"], RbConfig::CONFIG["ruby_install_name"])
  job_controller = Rails.root.join("script", "daemons", "job_task_processor_ctl.rb").to_s

  desc "Retart the job task processor"
  task :restart => :environment do
    system(ruby_exec, job_controller, "restart")
  end

  desc "Start the job task processor"
  task :start => :environment do
    system(ruby_exec, job_controller, "start")
  end

  desc "Stop the job task processor"
  task :stop => :environment do
    system(ruby_exec, job_controller, "stop")
  end
end
