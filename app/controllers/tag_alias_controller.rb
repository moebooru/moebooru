class TagAliasController < ApplicationController
  layout "default"
  before_action :member_only, :only => [:create]

  def create
    ta = TagAlias.new(params[:tag_alias].merge(:is_pending => true))

    if ta.save
      flash[:notice] = "Tag alias created"
    else
      flash[:notice] = "Error: " + ta.errors.full_messages.join(", ")
    end

    redirect_to :action => "index"
  end

  def index
    if params[:commit] == "Search Implications"
      redirect_to :controller => "tag_implication", :action => "index", :query => params[:query]
      return
    end

    if params[:query]
      name = "%" + params[:query].to_escaped_for_sql_like + "%"
      @aliases = TagAlias.paginate :order => "is_pending DESC, name", :per_page => 20, :conditions => ["name LIKE ? ESCAPE E'\\\\' OR alias_id IN (SELECT id FROM tags WHERE name ILIKE ? ESCAPE E'\\\\')", name, name], :page => page_number
    else
      @aliases = TagAlias.paginate :order => "is_pending DESC, name", :per_page => 20, :page => page_number
    end

    respond_to_list("aliases")
  end

  def update
    ids = params[:aliases].try(:keys)

    case params[:commit]
    when "Delete"
      if @current_user.is_mod_or_higher? || TagAlias.where(:id => ids, :is_pending => true, :creator_id => @current_user).count == ids.count
        ids.each { |x| TagAlias.find(x).destroy_and_notify(@current_user, params[:reason]) }

        flash[:notice] = "Tag aliases deleted"
        redirect_to :action => "index"
      else
        access_denied
      end

    when "Approve"
      if @current_user.is_mod_or_higher?
        ids.each do |x|
          if CONFIG["enable_asynchronous_tasks"]
            JobTask.create(:task_type => "approve_tag_alias", :status => "pending", :data => { "id" => x, "updater_id" => @current_user.id, "updater_ip_addr" => request.remote_ip })
          else
            TagAlias.find(x).approve(@current_user.id, request.remote_ip)
          end
        end

        flash[:notice] = "Tag alias approval jobs created"
        redirect_to :controller => "job_task", :action => "index"
      else
        access_denied
      end
    else
      head :bad_request
    end
  end
end
