class TagImplicationController < ApplicationController
  layout "default"
  before_action :member_only, :only => [:create]

  def create
    ti = TagImplication.new(tag_implication_params.merge(:is_pending => true, :creator_id => @current_user.id))

    if ti.save
      flash[:notice] = "Tag implication created"
    else
      flash[:notice] = "Error: " + ti.errors.full_messages.join(", ")
    end

    redirect_to :action => "index"
  end

  def update
    ids = params[:implications].try(:keys)

    case params[:commit]
    when "Delete"
      if @current_user.is_mod_or_higher? || TagImplication.where(:id => ids, :is_pending => true, :creator_id => @current_user.id).count == ids.count
        ids.each { |x| TagImplication.find(x).destroy_and_notify(@current_user, params[:reason]) }

        flash[:notice] = "Tag implications deleted"
        redirect_to :action => "index"
      else
        access_denied
      end

    when "Approve"
      if @current_user.is_mod_or_higher?
        ids.each do |x|
          if CONFIG["enable_asynchronous_tasks"]
            JobTask.create(:task_type => "approve_tag_implication", :status => "pending", :data => { "id" => x, "updater_id" => @current_user.id, "updater_ip_addr" => request.remote_ip })
          else
            TagImplication.find(x).approve(@current_user.id, request.remote_ip)
          end
        end

        flash[:notice] = "Tag implication approval jobs created"
        redirect_to :controller => "job_task", :action => "index"
      else
        access_denied
      end
    else
      head :bad_request
    end
  end

  def index
    if params[:commit] == "Search Aliases"
      return redirect_to :controller => "tag_alias", :action => "index", :query => params[:query]
    end

    # FIXME: subquery in order
    @implications = TagImplication.order(Arel.sql("is_pending DESC, (SELECT name FROM tags WHERE id = tag_implications.predicate_id), (SELECT name FROM tags WHERE id = tag_implications.consequent_id)"))

    if params[:query]
      tag_ids = Tag.where("name ILIKE ?", "*#{params[:query]}*".to_escaped_for_sql_like).select(:id)
      @implications = @implications
        .where("predicate_id IN (?) OR consequent_id IN (?)", tag_ids, tag_ids)
        .order(:is_pending => :desc, :consequent_id => :asc)
    end

    @implications = @implications.paginate :page => page_number, :per_page => 20

    respond_to_list("implications")
  end

  private

  def tag_implication_params
    params.require(:tag_implication).permit(:predicate, :consequent, :reason)
  end
end
