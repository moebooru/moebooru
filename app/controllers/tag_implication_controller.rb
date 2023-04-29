class TagImplicationController < ApplicationController
  layout 'default'
  before_action :member_only, {only: [:create]}

  def create
    ti = TagImplication.new(tag_implication_params.merge({is_pending: true, creator_id: @current_user.id}))
    flash[:notice] = ti.save ? 'Tag implication created' : 'Error: ' + ti.errors.full_messages.join(', ')
    redirect_to action: 'index'
  end

  def update
    ids = params[:implications].try(:keys)

    case params[:commit]
    when 'Delete'
      delete_tag_if_privileged_or_creator(ids)
    when 'Approve'
      approve_tag_if_privileged(ids)
    else
      head :bad_request
    end
  end

  def index
    if params[:commit] == 'Search Aliases'
      return redirect_to controller: 'tag_alias', action: 'index', query: params[:query]
    end

    # FIXME: subquery in order
    @implications = TagImplication.order(Arel.sql('is_pending DESC, (SELECT name FROM tags WHERE id = tag_implications.predicate_id), (SELECT name FROM tags WHERE id = tag_implications.consequent_id)'))

    if params[:query]
      tag_ids = Tag.where('name ILIKE ?', '*#{params[:query]}*'.to_escaped_for_sql_like).select(:id)
      @implications = @implications
        .where('predicate_id IN (?) OR consequent_id IN (?)', tag_ids, tag_ids)
        .order(is_pending: :desc, consequent_id: :asc)
    end

    @implications = @implications.paginate page: page_number, per_page: 20
    respond_to_list('implications')
  end

  private

  def approve_tag_if_privileged(ids)
    if @current_user.is_mod_or_higher?
      ids.each do |x|
        approve_tag(x)
      end

      flash[:notice] = 'Tag implication approval jobs created'
      redirect_to controller: 'job_task', action: 'index'
    else
      access_denied
    end
  end

  def approve_tag(x)
    if CONFIG['enable_asynchronous_tasks']
      JobTask.create({task_type: 'approve_tag_implication', status: 'pending', data: get_data(x)})
    else
      find_and_approve(x)
    end
  end

  def delete_tag_if_privileged_or_creator(ids)
    if @current_user.is_mod_or_higher? || get_creator_tag
      ids.each { |x| destroy_tag_and_notify_user(x) }

      flash[:notice] = 'Tag implications deleted'
      redirect_to action: 'index'
    else
      access_denied
    end
  end

  def destroy_tag_and_notify_user(x)
    TagImplication.find(x).destroy_and_notify(@current_user, params[:reason])
  end

  def tag_implication_params
    params.require(:tag_implication).permit(:predicate, :consequent, :reason)
  end

  def get_creator_tag
    return TagImplication.where(id: ids, is_pending: true, creator_id: @current_user.id).count == ids.count
  end

  def get_data(x)
    return {'id': x, 'updater_id': @current_user.id, 'updater_ip_addr': request.remote_ip}
  end

  def find_and_approve(x)
    TagImplication.find(x).approve(@current_user.id, request.remote_ip)
  end
end
