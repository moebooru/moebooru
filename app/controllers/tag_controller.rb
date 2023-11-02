# frozen_string_literal: true

class TagController < ApplicationController
  layout 'default'
  before_action :mod_only, only: %i[mass_edit edit_preview]
  before_action :member_only, only: %i[update edit]
  before_action :set_query_date, only: %i[popular_by_day popular_by_week popular_by_month]

  def cloud
    @tags = Tag.where('post_count > 0').order(post_count: :desc).limit(100).sort_by(&:name)
  end

  # Generates list of tag names matching parameter term.
  # Used by jquery-ui/autocomplete.
  def autocomplete_name
    @tags = Tag.where(['name ILIKE ?', "*#{params[:term]}*".to_escaped_for_sql_like]).order('LENGTH(name)', :name).limit(20).pluck(:name)
    respond_to do |format|
      format.json { render json: @tags }
    end
  end

  def summary
    if params[:version]
      # HTTP caching is unreliable for XHR.  If a version is supplied, and the version
      # hasn't changed since then, return an empty response.
      version = Tag.get_summary_version
      if params[:version].to_i == version
        render json: { version: version, unchanged: true }
        return
      end
    end

    # This string is already JSON-encoded, so don't call to_json.
    render json: Tag.get_json_summary
  end

  def index
    @tags = Tag.all
    populate_tags(limit_tags, order_tags)

    respond_to do |fmt|
      fmt.html
      fmt.xml
      fmt.json { render json: @tags }
    end
  end

  def mass_edit
    return unless request.post?

    check_missing_start_tag_param

    apply_mass_edit
  end

  def edit_preview
    @posts = Post.find_by_sql(Post.generate_sql(params[:tags], order: 'p.id DESC', limit: 500))
    render layout: false
  end

  def edit
    @edit = if params[:id]
              Tag.find(params[:id])
            else
              Tag.find_by_name(params[:name])
            end
    @edit ||= Tag.new
  end

  def update
    tag = Tag.find_by!(name: params[:tag][:name])
    tag.update(tag_params)

    respond_to_success('Tag updated', action: 'index')
  end

  def related
    @tags = Tag.scan_tags(params[:tags])

    tag_relation

    respond_with_tag_relation
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
      name = Tag.select(:name).find(params[:id]).name
    rescue StandardError
      raise ActionController::RoutingError, 'Not Found'
    end
    redirect_to controller: :wiki, action: :show, title: name
  end

  private

  def tag_params
    params.require(:tag).permit(:name, :tag_type, :is_ambiguous)
  end

  def limit_tags
    case params[:limit].presence
    when nil
      50
    when '0'
      request.format.html? ? 30 : nil
    else
      params[:limit].to_i
    end
  end

  def order_tags
    case params[:order]
    when 'count'
      'post_count desc'
    when 'date'
      'id desc'
    else
      'name'
    end
  end

  def tag_name_exist
    return @tags unless params[:name].present?

    keyword = if params[:name].include?('*')
                params[:name].to_escaped_for_sql_like
              else
                "*#{params[:name]}*".to_escaped_for_sql_like
              end
    @tags.where('name LIKE ?', keyword)
  end

  def filter_tag_type
    @tags.where(tag_type: params[:type].to_i) if params[:type].present?
  end

  def filter_tag_after_id
    @tags.where('id >= ?', params[:after_id].to_i) if params[:after_id].present?
  end

  def filter_tag_id
    @tags.where(id: params[:id].to_i) if params[:id].present?
  end

  def filter_tags
    filter_tag_type
    filter_tag_after_id
    filter_tag_id
    @tags
  end

  def limit_view(limit, order)
    if limit
      @tags.order(order).paginate(per_page: limit, page: page_number)
    else
      @tags.order(order)
    end
  end

  def populate_tags(limit, order)
    @tags = tag_name_exist

    @tags = filter_tags

    @tags = limit_view(limit, order)
  end

  def check_missing_start_tag_param
    return respond_to_error('Start tag missing', { action: 'mass_edit' }, status: 424) if params[:start].blank?
  end

  def create_mass_edit_async_job
    JobTask.create(task_type: 'mass_tag_edit', status: 'pending',
                   data: { 'start_tags' => params[:start], 'result_tags' => params[:result], 'updater_id' => session[:user_id], 'updater_ip_addr' => request.remote_ip })

    respond_to_success('Mass tag edit job created', controller: 'job_task', action: 'index')
  end

  def apply_mass_edit
    if CONFIG['enable_asynchronous_tasks']
      create_mass_edit_async_job
    else
      Tag.mass_edit(params[:start], params[:result], @current_user.id, request.remote_ip)
    end
  end

  def apply_tag_relation_by_type
    @tags = TagAlias.to_aliased(@tags)
    @tags = @tags.each_with_object({}) do |x, all|
      all[x] = Tag.calculate_related_by_type(x, CONFIG['tag_types'][params[:type]]).map { |y| [y['name'], y['post_count']] }
    end
  end

  def filter_tag_relation
    @patterns.each do |x|
      @tags[x] = Tag.where('name LIKE ?', x.to_escaped_for_sql_like).pluck(:name, :post_count)
    end
  end

  def apply_tag_relation_by_partition
    @patterns, @tags = @tags.partition { |x| x.include?('*') }
    @tags = TagAlias.to_aliased(@tags)
    @tags = @tags.each_with_object({}) do |x, all|
      all[x] = Tag.find_related(x).map { |y| [y[0], y[1]] }
    end
    filter_tag_relation
  end

  def tag_relation
    if params[:type].present?
      apply_tag_relation_by_type
    else
      apply_tag_relation_by_partition
    end
  end

  def construct_tag_relation
    builder.tag!('tags') do
      @tags.each do |parent, related|
        builder.tag!('tag', name: parent) do
          related.each do |tag, count|
            builder.tag!('tag', name: tag, count: count)
          end
        end
      end
    end
  end

  def respond_with_tag_relation
    respond_to do |fmt|
      fmt.xml do
        # We basically have to do this by hand.
        builder = Builder::XmlMarkup.new(indent: 2)
        builder.instruct!
        xml = construct_tag_relation

        render xml: xml
      end
      fmt.json { render json: @tags.to_json }
    end
  end
end
