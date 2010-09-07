class ReportController < ApplicationController
  layout 'default'
  before_filter :set_dates

  def tag_updates
    @users = Report.tag_updates(@start_date, @end_date)
    @report_title = "Tag Updates"
    @change_params = lambda {|user_id| {:controller => "post_tag_history", :action => "index", :user_id => user_id}}
    render :action => "common"
  end

  def note_updates
    @users = Report.note_updates(@start_date, @end_date)
    @report_title = "Note Updates"
    @change_params = lambda {|user_id| {:controller => "note", :action => "history", :user_id => user_id}}
    render :action => "common"
  end

  def wiki_updates
    @users = Report.wiki_updates(@start_date, @end_date)
    @report_title = "Wiki Updates"
    @change_params = lambda {|user_id| {:controller => "wiki", :action => "recent_changes", :user_id => user_id}}
    render :action => "common"
  end

  def post_uploads
    @users = Report.wiki_updates(@start_date, @end_date)
    @report_title = "Post Uploads"
    @change_params = lambda {|user_id| {:controller => "post", :action => "index", :tags => "user:#{User.find_name(user_id)}"}}
    render :action => "common"
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

private
  def set_dates
    if params[:start_date]
      @start_date = Date.parse(params[:start_date])
    else
      @start_date = 3.days.ago.to_date
    end

    if params[:end_date]
      @end_date = Date.parse(params[:end_date])
    else
      @end_date = Date.today
    end
  end
end
