require "versioning"

class HistoryController < ApplicationController
  layout "default"
  #  before_filter :member_only

  def index
    search = params[:search] || ""

    q = Hash.new { |h, k| h[k] = [] }

    search.split(" ").each do |s|
      if s =~ /^(.+?):(.*)/
        search_type = Regexp.last_match[1]
        param = Regexp.last_match[2]

        if search_type == "user"
          q[:user] = param
        elsif search_type == "change"
          q[:change] = param.to_i
        elsif search_type == "type"
          q[:type] = param
        elsif search_type == "id"
          q[:id] = param.to_i
        elsif search_type == "field"
          # :type must also be set for this to be used.
          q[:field] = param
        else
          # pool:123
          q[:type] = search_type
          q[:id] = param.to_i
        end
      else
        q[:keywords] << s
      end
    end

    q[:type] = q[:type].pluralize if q.key?(:type)
    q[:inner_type] = q[:inner_type].pluralize if q.key?(:inner_type)

    # If notes:id has been specified, search using the inner key in history_changes
    # rather than the grouping table in histories.  We don't expose this in general.
    # Searching based on hc.table_name without specifying an ID is slow, and the
    # details here shouldn't be visible anyway.
    if q.key?(:type) && q.key?(:id) && q[:type] == "notes"
      q[:inner_type] = q[:type]
      q[:remote_id] = q[:id]

      q.delete(:type)
      q.delete(:id)
    end

    conds = []
    cond_params = []

    hc_conds = []
    hc_cond_params = []

    if q[:user].is_a?(String)
      user = User.find_by_name(q[:user])
      if user
        conds << "histories.user_id = ?"
        cond_params << user.id
      else
        conds << "false"
      end
    end

    if q.key?(:id)
      conds << "group_by_id = ?"
      cond_params << q[:id]
    end

    if q.key?(:type)

      conds << "group_by_table = ?"
      cond_params << q[:type]
    end

    if q.key?(:change)
      conds << "histories.id = ?"
      cond_params << q[:change]
    end

    if q.key?(:type)
      conds << "group_by_table = ?"
      cond_params << q[:type]
    end

    if q.key?(:inner_type)
      q[:inner_type] = q[:inner_type].pluralize

      hc_conds << "hc.table_name = ?"
      hc_cond_params << q[:inner_type]
    end

    if q.key?(:remote_id)
      hc_conds << "hc.remote_id = ?"
      hc_cond_params << q[:remote_id]
    end

    if q[:keywords].any?
      hc_conds << "hc.value_array @> ARRAY[?]::varchar[]"
      hc_cond_params << Array(q[:keywords])
    end

    if q.key?(:field) && q.key?(:type)
      # Look up a particular field change, eg. "type:posts field:rating".
      # XXX: The WHERE id IN (SELECT id...) used to implement this is slow when we don't have
      # anything else filtering the results.
      field = q[:field]
      table = q[:type]

      # For convenience:
      field = "cached_tags" if field == "tags"

      # Look up the named class.
      cls = Versioned.get_versioned_classes_by_name[table]
      if cls.nil?
        conds << "false"
      else
        hc_conds << "hc.column_name = ?"
        hc_cond_params << field

        # A changes that has no previous value is the initial value for that object.  Don't show
        # these changes unless they're different from the default for that field.
        default_value, has_default = cls.get_versioned_default(field.to_sym)
        if has_default
          hc_conds << "(hc.previous_id IS NOT NULL OR value <> ?)"
          hc_cond_params << default_value
        end
      end
    end

    if hc_conds.any?
      conds << """histories.id IN (SELECT history_id FROM history_changes hc JOIN histories h ON (hc.history_id = h.id) WHERE #{hc_conds.join(" AND ")})"""
      cond_params += hc_cond_params
    end

    if q.key?(:type) && !q.key?(:change)
      @type = q[:type]
    else
      @type = "all"
    end

    # :specific_history => showing only one history
    # :specific_table => showing changes only for a particular table
    # :show_all_tags => don't omit post tags that didn't change
    @options = {
      :show_all_tags => params[:show_all_tags] == "1",
      :specific_object => (q.key?(:type) && q.key?(:id)),
      :specific_history => q.key?(:change)
    }

    @options[:show_name] = false
    if @type != "all"
      suppress NameError do
        obj = Object.const_get(@type.classify)
        @options[:show_name] = obj.method_defined?("pretty_name")
      end
    end

    @changes = History
      .includes(:history_changes)
      .where(conds.join(" AND "), *cond_params)
      .order(:id => :desc)
      .paginate(:per_page => 20, :page => page_number)

    # If we're searching for a specific change, force the display to the
    # type of the change we found.
    if q.key?(:change) && !@changes.empty?
      @type = @changes.first.group_by_table.pluralize
    end

    respond_to { |format| format.html }
  end

  def undo
    ids = params[:id].split(/,/)

    @changes = HistoryChange.where(:id => ids)
    histories = @changes.map(&:history_id).uniq

    if histories.count > 1 && !@current_user.is_privileged_or_higher?
      respond_to_error("Only privileged users can undo more than one change at once", :status => 403)
      return
    end

    errors = {}
    History.undo(@changes, @current_user, params[:redo] == "1", errors)

    error_texts = []
    errors.each do |error|
      case error
      when :denied
        error_texts << "Some changes were not made because you do not have access to make them."
      end
    end
    error_texts.uniq!

    failed = errors.count
    successful = @changes.count - failed

    respond_to_success("Changes made.", { :action => "index" }, :api => { :successful => successful, :failed => failed, :errors => error_texts })
  end
end
