class TagImplicationController < ApplicationController
  layout 'default'
  before_action :member_only, only: [:create]

  def create
    ti = TagImplication.new(tag_implication_params.merge(is_pending: true, creator_id: @current_user.id))
    flash[:notice] = ti.save ? 'Tag implication created' : "Error: #{ti.errors.full_messages.join(', ')}"
    redirect_to action: 'index'
  end

  def update
    ids = params[:implications].try(:keys)

    case params[:commit]
    when 'Delete'
      delete_tags(ids)
    when 'Approve'
      approve_tags(ids)
    else
      head :bad_request
    end
  end

  def index
    redirect_to_tag_alias_index if searching_aliases?

    @implications = retrieve_matching_tag_id
    apply_query_filter
    paginate_implications
    respond_to_list('implications')
  end

  private

  def redirect_to_tag_alias_index
    redirect_to(controller: 'tag_alias', action: 'index', query: params[:query])
  end

  def searching_aliases?
    params[:commit] == 'Search Aliases'
  end

  def apply_query_filter
    return unless params[:query].present?

    @implications = retrieve_tag_with_matching_id_and_name(params[:query])
  end

  def paginate_implications
    @implications = @implications.paginate(page: page_number, per_page: 20)
  end

  def page_number
    params[:page] || 1
  end

  def retrieve_matching_tag_id
    TagImplication.order(Arel.sql('is_pending DESC, (SELECT name FROM tags WHERE id = tag_implications.predicate_id), (SELECT name FROM tags WHERE id = tag_implications.consequent_id)'))
  end

  def retrieve_tag_with_matching_id_and_name(query)
    tag_ids = Tag.where('name ILIKE :query', query: "%#{query}%").select(:id)
    @implications
      .where('predicate_id IN (:tag_ids) OR consequent_id IN (:tag_ids)', tag_ids: tag_ids)
      .order(is_pending: :desc, consequent_id: :asc)
  end

  def approve_tags(ids)
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
      JobTask.create(task_type: 'approve_tag_implication', status: 'pending', data: format_with_user_info(x))
    else
      find_and_approve(x)
    end
  end

  def delete_tags(ids)
    if @current_user.is_mod_or_higher? || check_creator_tag(ids)
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

  def check_creator_tag(ids)
    TagImplication.where(id: ids, is_pending: true, creator_id: @current_user.id).count == ids.count
  end

  def format_with_user_info(x)
    { 'id': x, 'updater_id': @current_user.id, 'updater_ip_addr': request.remote_ip }
  end

  def find_and_approve(x)
    TagImplication.find(x).approve(@current_user.id, request.remote_ip)
  end
end
