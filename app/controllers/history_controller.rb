class HistoryController < ApplicationController
  layout 'default'
#  before_filter :member_only
  verify :method => :post, :only => [:undo]
 
  def index
    set_title "History"

    @params = params
    if params[:action] == "index"
      @type = "all"
    else
      @type = params[:action].pluralize
    end

    conds = []
    cond_params = []
    # :specific_history => showing only one history
    # :specific_table => showing changes only for a particular table
    # :show_all_tags => don't omit post tags that didn't change
    @options = {
      :show_all_tags => @params[:show_all_tags] == "1"
    }
    set_type_to_result = false
    search_type = param = nil
    search = params[:search] || ""
    value_index_query = []
    search.split(' ').each { |s|
      # If a search specifies a table name, it overrides the action.
      if s =~ /^(.+?):(.*)/
        search_type = $1
        param = $2

        if search_type == "user"
          user = User.find_by_name(param)
          if user
            conds << "histories.user_id = ?"
            cond_params << user.id
          else
            conds << "false"
          end
        elsif search_type == "change"
          @type = "all"
          @options[:specific_history] = true
          conds << "histories.id = ?"
          cond_params << param.to_i

          set_type_to_result = true
        else
          @options[:specific_table] = true
          @type = search_type.pluralize
          conds << "histories.group_by_id = ?"
          cond_params << param.to_i
        end
      else
        value_index_query << "(" + Post.geneate_sql_escape_helper(s).join(" | ") + ")"
      end
    }

    if value_index_query.any?
      conds << "value_index @@ to_tsquery('danbooru', E'" + value_index_query.join(" & ") + "')"
    end

    if @type != "all"
      conds << "histories.group_by_table = ?"
      cond_params << @type
    end

    @options[:show_name] = false
    if @type != "all"
      begin
        obj = Object.const_get(@type.classify)
        @options[:show_name] = obj.method_defined?("pretty_name")
      rescue NameError => e
      end
    end

    @changes = History.paginate(History.generate_sql(params).merge(
      :order => "histories.id DESC", :per_page => 20, :select => "histories.*", :page => params[:page],
      :joins => "JOIN history_changes ON (histories.id = history_changes.history_id)",
      :conditions => [conds.join(" AND "), *cond_params],
      :include => [:history_changes]
    ))

    # If we're searching for a specific change, force the display to the
    # type of the change we found.
    if set_type_to_result && !@changes.empty?
      @type = @changes.first.group_by_table.pluralize
    end

    render :action => :index
  end
  
  alias_method :post, :index
  alias_method :pool, :index
  alias_method :tag, :index

  def undo
    ids = params[:id].split(/,/)
    
    @changes = []
    ids.each do |id|
      @changes += HistoryChange.find(:all, :conditions => ["id = ?", id])
    end

    histories = {}
    total_histories = 0
    @changes.each { |change|
      next if histories[change.history_id]
      histories[change.history_id] = true
      total_histories += 1
    }

    if total_histories > 1 && !@current_user.is_privileged_or_higher?
      respond_to_error("Only privileged users can undo more than one change at once", :status => 403)
      return
    end

    errors = {}
    History.undo(@changes, @current_user, params[:redo] == "1", errors)

    error_texts = []
    successful = 0
    failed = 0
    @changes.each { |change|
      if not errors[change]
        successful += 1
        next
      end
      failed += 1

      case errors[change]
      when :denied
        error_texts << "Some changes were not made because you do not have access to make them."
      end
    }
    error_texts.uniq!

    respond_to_success("Changes made.", {:action => "index"}, :api => {:successful=>successful, :failed=>failed, :errors=>error_texts})
  end
end
