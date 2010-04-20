class ReportController < ApplicationController
  layout 'default'
  
  def tag_changes
    @users = Report.usage_by_user("histories", 3.days.ago, Time.now, ["group_by_table = ?"], ["posts"])
    GoogleChart::PieChart.new("600x300", "Tag Changes", false) do |pc|
      @users.each do |user|
        # Hack to work around the limited Google API: there's no way to send a literal
        # pipe, since that's the field separator, and it won't render any of the alternate
        # pipe-like characters.
        pc.data user["name"].gsub(/\|/, 'l'), user["change_count"].to_i
      end
      
      @tag_changes_url = pc.to_url
    end
  end
  
  def note_changes
    @users = Report.usage_by_user("note_versions", 3.days.ago, Time.now)
    GoogleChart::PieChart.new("600x300", "Note Changes", false) do |pc|
      @users.each do |user|
        pc.data user["name"].gsub(/\|/, 'l'), user["change_count"].to_i
      end
      
      @note_changes_url = pc.to_url
    end
  end
  
  def wiki_changes
    @users = Report.usage_by_user("wiki_page_versions", 3.days.ago, Time.now)
    GoogleChart::PieChart.new("600x300", "Wiki Changes", false) do |pc|
      @users.each do |user|
        pc.data user["name"].gsub(/\|/, 'l'), user["change_count"].to_i
      end
      
      @wiki_changes_url = pc.to_url
    end
  end
  
  def votes
    start = 3.days.ago
    stop = Time.now
    @users = Report.usage_by_user("post_votes", start, stop, ["score > 0"], [], "updated_at")
    GoogleChart::PieChart.new("600x300", "Votes", false) do |pc|
      @users.each do |user|
        pc.data user["name"].gsub(/\|/, 'l'), user["change_count"].to_i
      end
      
      @votes_url = pc.to_url
    end

    @users.each do |user|
      conds = ["updated_at BETWEEN ? AND ?"]
      params = []
      params << start
      params << stop

      if user["user"] then
        conds << "user_id = ?"
        params << user["user_id"]
      else
        conds << "user_id NOT IN (?)"
        params << @users.select {|x| x["user_id"]}.map {|x| x["user_id"]}
      end

      votes = ActiveRecord::Base.connection.select_all(ActiveRecord::Base.sanitize_sql(["SELECT COUNT(score) AS sum, score FROM post_votes WHERE #{conds.join(" AND ")} GROUP BY score", *params]))
      user["votes"] = {}
      votes.each { |vote|
        score = vote["score"].to_i
        user["votes"][score] = vote["sum"]
      }
    end

  end
end
