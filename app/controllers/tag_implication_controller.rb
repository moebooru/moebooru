class TagImplicationController < ApplicationController
  layout "default"
  before_filter :member_only, :only => [:create]

  def create
    ti = TagImplication.new(params[:tag_implication].merge(:is_pending => true))

    if ti.save
      flash[:notice] = "Tag implication created"
    else
      flash[:notice] = "Error: " + ti.errors.full_messages.join(", ")
    end

    redirect_to :action => "index"
  end

  def update
    ids = params[:implications].keys

    case params[:commit]
    when "Delete"
      if @current_user.is_mod_or_higher? || ids.all? {|x| ti = TagImplication.find(x) ; ti.is_pending? && ti.creator_id == @current_user.id}
        ids.each {|x| TagImplication.find(x).destroy_and_notify(@current_user, params[:reason])}

        flash[:notice] = "Tag implications deleted"
        redirect_to :action => "index"
      else
        access_denied
      end

    when "Approve"
      if @current_user.is_mod_or_higher?
        ids.each do |x|
          if CONFIG["enable_asynchronous_tasks"]
            JobTask.create(:task_type => "approve_tag_implication", :status => "pending", :data => {"id" => x, "updater_id" => @current_user.id, "updater_ip_addr" => request.remote_ip})
          else
            TagImplication.find(x).approve(@current_user.id, request.remote_ip)
          end
        end

        flash[:notice] = "Tag implication approval jobs created"
        redirect_to :controller => "job_task", :action => "index"
      else
        access_denied
      end
    end
  end

  def index
    if params[:commit] == "Search Aliases"
      return redirect_to :controller => "tag_alias", :action => "index", :query => params[:query]
    end

    if params[:query]
      name = "%" + params[:query].to_escaped_for_sql_like + "%"
      @implications = TagImplication.paginate :order => "is_pending DESC, (SELECT name FROM tags WHERE id = tag_implications.predicate_id), (SELECT name FROM tags WHERE id = tag_implications.consequent_id)", :per_page => 20, :conditions => ["predicate_id IN (SELECT id FROM tags WHERE name ILIKE ? ESCAPE '\\') OR consequent_id IN (SELECT id FROM tags WHERE name ILIKE ? ESCAPE '\\')", name, name], :page => page_number
    else
      @implications = TagImplication.paginate :order => "is_pending DESC, (SELECT name FROM tags WHERE id = tag_implications.predicate_id), (SELECT name FROM tags WHERE id = tag_implications.consequent_id)", :per_page => 20, :page => page_number
    end

    respond_to_list("implications")
  end
end
