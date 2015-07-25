class TagController < ApplicationController
  layout "default"
  before_action :mod_only, :only => [:mass_edit, :edit_preview]
  before_action :member_only, :only => [:update, :edit]
  before_action :set_query_date, :only => [:popular_by_day, :popular_by_week, :popular_by_month]

  def cloud
    @tags = Tag.where("post_count > 0").order(:post_count => :desc).limit(100).sort { |a, b| a.name <=> b.name }
  end

  # Generates list of tag names matching parameter term.
  # Used by jquery-ui/autocomplete.
  def autocomplete_name
    @tags = Tag.where(["name ILIKE ?", "*#{params[:term]}*".to_escaped_for_sql_like]).pluck(:name)
    respond_to do |format|
      format.json { render :json => @tags }
    end
  end

  def summary
    if params[:version]
      # HTTP caching is unreliable for XHR.  If a version is supplied, and the version
      # hasn't changed since then, return an empty response.
      version = Tag.get_summary_version
      if params[:version].to_i == version
        render :json => { :version => version, :unchanged => true }
        return
      end
    end

    # This string is already JSON-encoded, so don't call to_json.
    render :json => Tag.get_json_summary
  end

  def index
    limit = case params[:limit].presence
            when nil
              50
            when "0"
              request.format.html? ? 30 : nil
            else
              params[:limit].to_i
            end

    order = case params[:order]
            when "count"
              "post_count desc"
            when "date"
              "id desc"
            else
              "name"
            end

    @tags = Tag.all

    if params[:name].present?
      keyword = if params[:name].include? "*"
                  params[:name].to_escaped_for_sql_like
                else
                  "*#{params[:name]}*".to_escaped_for_sql_like
                end
      @tags = @tags.where "name LIKE ?", keyword
    end

    if params[:type].present?
      @tags = @tags.where :tag_type => params[:type].to_i
    end

    if params[:after_id].present?
      @tags = @tags.where "id >= ?", params[:after_id].to_i
    end

    if params[:id].present?
      @tags = @tags.where :id => params[:id].to_i
    end

    @tags = if limit
              @tags.order(order).paginate :per_page => limit, :page => page_number
            else
              @tags.order order
            end

    respond_to do |fmt|
      fmt.html
      fmt.xml
      fmt.json { render :json => @tags }
    end
  end

  def mass_edit
    if request.post?
      if params[:start].blank?
        respond_to_error("Start tag missing", { :action => "mass_edit" }, :status => 424)
        return
      end

      if CONFIG["enable_asynchronous_tasks"]
        JobTask.create(:task_type => "mass_tag_edit", :status => "pending", :data => { "start_tags" => params[:start], "result_tags" => params[:result], "updater_id" => session[:user_id], "updater_ip_addr" => request.remote_ip })
        respond_to_success("Mass tag edit job created", :controller => "job_task", :action => "index")
      else
        Tag.mass_edit(params[:start], params[:result], @current_user.id, request.remote_ip)
      end
    end
  end

  def edit_preview
    @posts = Post.find_by_sql(Post.generate_sql(params[:tags], :order => "p.id DESC", :limit => 500))
    render :layout => false
  end

  def edit
    if params[:id]
      @tag = Tag.find(params[:id])
    else
      @tag = Tag.find_by_name(params[:name])
    end
    @tag ||= Tag.new
  end

  def update
    tag = Tag.find_by!(:name => params[:tag][:name])
    tag.update(tag_params)

    respond_to_success("Tag updated", :action => "index")
  end

  def related
    if params[:type].present?
      @tags = Tag.scan_tags(params[:tags])
      @tags = TagAlias.to_aliased(@tags)
      @tags = @tags.reduce({}) do |all, x|
        all[x] = Tag.calculate_related_by_type(x, CONFIG["tag_types"][params[:type]]).map { |y| [y["name"], y["post_count"]] }
        all
      end
    else
      @tags = Tag.scan_tags(params[:tags])
      @patterns, @tags = @tags.partition { |x| x.include?("*") }
      @tags = TagAlias.to_aliased(@tags)
      @tags = @tags.reduce({}) do |all, x|
        all[x] = Tag.find_related(x).map { |y| [y[0], y[1]] }
        all
      end
      @patterns.each do |x|
        @tags[x] = Tag.where("name LIKE ?", x.to_escaped_for_sql_like).pluck(:name, :post_count)
      end
    end

    respond_to do |fmt|
      fmt.xml do
        # We basically have to do this by hand.
        builder = Builder::XmlMarkup.new(:indent => 2)
        builder.instruct!
        xml = builder.tag!("tags") do
          @tags.each do |parent, related|
            builder.tag!("tag", :name => parent) do
              related.each do |tag, count|
                builder.tag!("tag", :name => tag, :count => count)
              end
            end
          end
        end

        render :xml => xml
      end
      fmt.json { render :json => @tags.to_json }
    end
  end

  def popular_by_day
    @day = @query_date.beginning_of_day

    @tags = Tag.count_by_period(@day, @day.end_of_day)
  end

  def popular_by_week
    @day = @query_date.beginning_of_week

    @tags = Tag.count_by_period(@day, @day.end_of_week)
  end

  def popular_by_month
    @day = @query_date.beginning_of_month

    @tags = Tag.count_by_period(@day, @day.end_of_month)
  end

  def show
    begin
      name = Tag.find(params[:id], :select => :name).name
    rescue
      raise ActionController::RoutingError.new("Not Found")
    end
    redirect_to :controller => :wiki, :action => :show, :title => name
  end

  private

  def tag_params
    params.require(:tag).permit(:name, :tag_type, :is_ambiguous)
  end
end
