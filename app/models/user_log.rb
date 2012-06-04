class UserLog < ActiveRecord::Base
  def self.access(user, request)
    return if user.is_anonymous?

    # Only do this periodically, so we don't do extra work for every request.
    old_ip = Rails.cache.read("userip:#{user.id}")

    return if !old_ip.nil? && old_ip == request.remote_ip

    execute_sql("SELECT * FROM user_logs_touch(?, ?)", user.id, request.remote_ip)

    # Clean up old records.
    execute_sql("DELETE FROM user_logs WHERE created_at < now() - interval '3 days'")

    Rails.cache.write("userip:#{user.id}", request.remote_ip, :expires_in => 8.seconds)
  end
end
