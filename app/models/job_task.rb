class JobTask < ActiveRecord::Base
  TASK_TYPES = %w(mass_tag_edit approve_tag_alias approve_tag_implication calculate_tag_subscriptions upload_posts_to_mirrors periodic_maintenance upload_batch_posts update_post_frames)
  STATUSES = %w(pending processing finished error)

  validates_inclusion_of :task_type, :in => TASK_TYPES
  validates_inclusion_of :status, :in => STATUSES

  def data
    JSON.parse(data_as_json)
  end

  def data=(hoge)
    self.data_as_json = hoge.to_json
  end

  def execute!
    if repeat_count > 0
      count = repeat_count - 1
    else
      count = repeat_count
    end

    begin
      execute_sql("SET statement_timeout = 0")
      update_attributes(:status => "processing")
      __send__("execute_#{task_type}")

      if count == 0
        update_attributes(:status => "finished")
      else
        update_attributes(:status => "pending", :repeat_count => count)
      end
    rescue SystemExit => x
      update_attributes(:status => "pending")
      raise x
    rescue Exception => x
      text = "\n\n"
      text << "Error executing job: #{task_type}\n"
      text << "    "
      text << x.backtrace.join("\n    ")
      logger.fatal(text)

      update_attributes(:status => "error", :status_message => "#{x.class}: #{x}")
    end
  end

  def execute_mass_tag_edit
    start_tags = data["start_tags"]
    result_tags = data["result_tags"]
    updater_id = data["updater_id"]
    updater_ip_addr = data["updater_ip_addr"]
    Tag.mass_edit(start_tags, result_tags, updater_id, updater_ip_addr)
  end

  def execute_approve_tag_alias
    ta = TagAlias.find(data["id"])
    updater_id = data["updater_id"]
    updater_ip_addr = data["updater_ip_addr"]
    ta.approve(updater_id, updater_ip_addr)
  end

  def execute_approve_tag_implication
    ti = TagImplication.find(data["id"])
    updater_id = data["updater_id"]
    updater_ip_addr = data["updater_ip_addr"]
    ti.approve(updater_id, updater_ip_addr)
  end

  def execute_calculate_tag_subscriptions
    return if Rails.cache.read("delay-tag-sub-calc")
    Rails.cache.write("delay-tag-sub-calc", "1", :expires_in => 360.minutes)
    TagSubscription.process_all
    update_attributes(:data => { :last_run => Time.now.strftime("%Y-%m-%d %H:%M") })
  end

  def update_data(*args)
    hash = data.merge(args[0])
    update_attributes(:data => hash)
  end

  def execute_periodic_maintenance
    return if data["next_run"] && data["next_run"] > Time.now.to_i

    update_data("step" => "recalculating post count")
    Post.recalculate_row_count
    update_data("step" => "recalculating tag post counts")
    Tag.recalculate_post_count
    update_data("step" => "purging old tags")
    Tag.purge_tags

    update_data("next_run" => Time.now.to_i + 60 * 60 * 6, "step" => nil)
  end

  def execute_upload_posts_to_mirrors
    # This is a little counterintuitive: if we're backlogged, mirror newer posts first,
    # since they're the ones that receive the most attention.  Mirror held posts after
    # unheld posts.
    #
    # Apply a limit, so if we're backlogged heavily, we'll only upload a few posts and
    # then give other jobs a chance to run.
    data = {}
    (1..10).each do
      post = Post.find(:first, :conditions => ["NOT is_warehoused AND status <> 'deleted'"], :order => "is_held ASC, index_timestamp DESC")
      break if !post

      data["left"] = Post.count(:conditions => ["NOT is_warehoused AND status <> 'deleted'"])
      data["post_id"] = post.id
      update_attributes(:data => data)

      begin
        post.upload_to_mirrors
      ensure
        data["post_id"] = nil
        update_attributes(:data => data)
      end

      data["left"] = Post.count(:conditions => ["NOT is_warehoused AND status <> 'deleted'"])
      update_attributes(:data => data)
    end
  end

  def execute_upload_batch_posts
    upload = BatchUpload.find(:first, :conditions => ["status = 'pending'"], :order => "id ASC")
    if upload.nil? then return end

    update_attributes(:data => { :id => upload.id, :user_id => upload.user_id, :url => upload.url })
    upload.run
  end

  def execute_update_post_frames
    update_status = Proc.new do |status|
      update_data("status" => status)
    end

    # Do a limited number of operations to update frames, then move on.
    (1..10).each do
      # Do one step, then move on.
      next if PostFrames.process_frames(update_status)
      next if PostFrames.warehouse_frames(update_status)
      next if PostFrames.purge_frames(update_status)

      # There's nothing more to do.
      return
    end
  end

  def pretty_data
    case task_type
    when "mass_tag_edit"
      start = data["start_tags"]
      result = data["result_tags"]
      user = User.find_name(data["updater_id"])

      "start:#{start} result:#{result} user:#{user}"

    when "approve_tag_alias"
      ta = TagAlias.find(data["id"])
      "start:#{ta.name} result:#{ta.alias_name}"

    when "approve_tag_implication"
      ti = TagImplication.find(data["id"])
      "start:#{ti.predicate.name} result:#{ti.consequent.name}"

    when "calculate_tag_subscriptions"
      last_run = data["last_run"]
      "last run:#{last_run}"

    when "upload_posts_to_mirrors"
      ret = ""
      if data["post_id"]
        ret << "uploading post_id #{data["post_id"]}"
      elsif data["left"]
        ret << "sleeping"
      else
        ret << "idle"
      end
      ret << (" (%i left) " % data["left"]) if data["left"]
      ret

    when "periodic_maintenance"
      if status == "processing" then
        data["step"]
      elsif status != "error" then
        next_run = (data["next_run"] || 0) - Time.now.to_i
        next_run_in_minutes = next_run.to_i / 60
        if next_run_in_minutes > 0
          eta = "next run in #{(next_run_in_minutes.to_f / 60.0).round} hours"
        else
          eta = "next run imminent"
        end
        "sleeping (#{eta})"
      end

    when "upload_batch_posts"
      if status == "pending" then
        return "idle"
      elsif status == "processing" then
        user = User.find_name(data["user_id"])
        return "uploading #{data["url"]} for #{user}"
      end
    when "update_post_frames"
      if status == "pending" then
        return "idle"
      elsif status == "processing" then
        return data["status"]
      end
    end
  end

  def self.execute_once
    find(:all, :conditions => ["status = ?", "pending"], :order => "id desc").each do |task|
      task.execute!
      sleep 1
    end
  end

  def self.execute_all
    # If we were interrupted without finishing a task, it may be left in processing; reset
    # thos tasks to pending.
    find(:all, :conditions => ["status = ?", "processing"]).each do |task|
      task.update_attributes(:status => "pending")
    end

    while true
      execute_once
      sleep 10
    end
  end
end
