module Report
  def usage_by_user(table_name, start, stop, limit, level, conds = [], params = [], column = "created_at")
    conds << ["#{table_name}.#{column} BETWEEN ? AND ?"]
    params << start
    params << stop

    if level && level != 0
      conds << "users.level = ?"
      params << level
    end

    users = ActiveRecord::Base.select_all_sql("SELECT users.id, COUNT(*) as change_count FROM #{table_name} JOIN users ON users.id = #{table_name}.user_id WHERE " + conds.join(" AND ") + " GROUP BY users.id ORDER BY change_count DESC LIMIT #{limit}", *params).to_a

    conds << "users.id NOT IN (?)"
    params << users.map { |x| x["id"] }

    other_count = ActiveRecord::Base.connection.select_value(ActiveRecord::Base.sanitize_sql_array(["SELECT COUNT(*) FROM #{table_name} JOIN users ON users.id = #{table_name}.user_id WHERE " + conds.join(" AND "), *params])).to_i

    users << { "id" => nil, "change_count" => other_count }

    users.each do |user|
      user["change_count"] = user["change_count"].to_i
      if user["id"]
        user["user"] = User.find(user["id"])
        user["name"] = user["user"].name
      else
        user["name"] = "Other"
      end
    end

    add_sum(users)
  end

  def tag_updates(start, stop, limit, level)
    users = usage_by_user("post_tag_histories", start, stop, limit, level)
    users.each do |user|
      user["change_count"] = user["change_count"] - Post.where(:user_id => user["user_id"]).where("created_at BETWEEN ? AND ?", start, stop).count
    end
    bottom = users.pop
    users.sort! { |a, b| b["change_count"] <=> a["change_count"] }
    users.push(bottom)
    users
  end

  def post_uploads(start, stop, limit, level)
    usage_by_user("posts", start, stop, limit, level)
  end

  def wiki_updates(start, stop, limit, level)
    usage_by_user("wiki_page_versions", start, stop, limit, level)
  end

  def note_updates(start, stop, limit, level)
    usage_by_user("note_versions", start, stop, limit, level)
  end

  def add_sum(users)
    sum = 0
    users.each do |user|
      sum += user["change_count"]
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
