module Report
  def usage_by_user(table_name, start, stop, conds = [], params = [], column = "created_at")
    conds << ["%s BETWEEN ? AND ?" % column]
    params << start
    params << stop

    users = ActiveRecord::Base.select_all_sql("SELECT user_id, COUNT(*) as change_count FROM #{table_name} WHERE " + conds.join(" AND ") + " GROUP BY user_id ORDER BY change_count DESC LIMIT 29", *params)

    conds << "user_id NOT IN (?)"
    params << users.map {|x| x["user_id"]}

    other_count = ActiveRecord::Base.connection.select_value(ActiveRecord::Base.sanitize_sql(["SELECT COUNT(*) FROM #{table_name} WHERE " + conds.join(" AND "), *params])).to_i
    
    users << {"user_id" => nil, "change_count" => other_count}
    
    users.each do |user|
      if user["user_id"]
        user["user"] = User.find(user["user_id"])
        user["name"] = user["user"].name
      else
        user["name"] = "Other"
      end
    end
    
    return add_sum(users)
  end
  
  def tag_updates(start, stop)
    users = usage_by_user("post_tag_histories", start, stop)
    users.each do |user|
      user["change_count"] = user["change_count"] - Post.count(:all, :conditions => ["created_at BETWEEN ? AND ? AND user_id = ? AND status = 'active'", start, stop, user["user_id"]])
    end
    users
  end

  def post_uploads(start, stop)
    usage_by_user("posts", start, stop)
  end

  def wiki_updates(start, stop)
    usage_by_user("wiki_page_versions", start, stop)
  end

  def note_updates(start, stop)
    usage_by_user("note_versions", start, stop)
  end

  def add_sum(users)
    sum = 0
    users.each do |user|
      sum += user["change_count"].to_i
    end
    users.each do |user|
      user["sum"] = sum.to_f
    end
  end

  module_function :usage_by_user
  module_function :tag_updates
  module_function :post_uploads
  module_function :wiki_updates
  module_function :note_updates
  module_function :add_sum
end
