# frozen_string_literal: true

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
    return redirect_to_tag_alias_index if searching_aliases?

    @implications = TagImplication.retrieve_matching_tag_id
    @implications = TagImplication.apply_query_filter(params[:query], @implications)
    @implications = TagImplication.paginate(page: page_number, per_page: 20)
    respond_to_list('implications')
  end

  private

  def redirect_to_tag_alias_index
    redirect_to(controller: 'tag_alias', action: 'index', query: params[:query])
  end

  def searching_aliases?
    params[:commit] == 'Search Aliases'
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
    { id: x, updater_id: @current_user.id, updater_ip_addr: request.remote_ip }
  end

  def find_and_approve(x)
    TagImplication.find(x).approve(@current_user.id, request.remote_ip)
  end
end
