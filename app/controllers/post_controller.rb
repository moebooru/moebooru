require "download"

class PostController < ApplicationController
  layout 'default'
  helper :avatar

  verify :method => :post, :only => [:update, :destroy, :create, :revert_tags, :vote, :flag], :redirect_to => {:action => :show, :id => lambda {|c| c.params[:id]}}

  before_filter :member_only, :only => [:create, :destroy, :delete, :flag, :revert_tags, :activate, :update_batch]
  before_filter :post_member_only, :only => [:update, :upload, :flag]
  before_filter :janitor_only, :only => [:moderate, :undelete]
  after_filter :save_tags_to_cookie, :only => [:update, :create]
  if CONFIG["load_average_threshold"]
    before_filter :check_load_average, :only => [:index, :popular_by_day, :popular_by_week, :popular_by_month, :random, :atom, :piclens]
  end
  
  if CONFIG["enable_caching"]
    around_filter :cache_action, :only => [:index, :atom, :piclens]
  end

  helper :wiki, :tag, :comment, :pool, :favorite, :advertisement

  def verify_action(options)
    redirect_to_proc = false
    
    if options[:redirect_to] && options[:redirect_to][:id].is_a?(Proc)
      redirect_to_proc = options[:redirect_to][:id]
      options[:redirect_to][:id] = options[:redirect_to][:id].call(self)
    end
    
    result = super(options)
  	
    if redirect_to_proc
      options[:redirect_to][:id] = redirect_to_proc
    end
	  
    return result
  end
  
  def activate
    ids = params[:post_ids].map { |id| id.to_i }
    changed = Post.batch_activate(@current_user.is_mod_or_higher? ? nil: @current_user.id, ids)
    respond_to_success("Posts activated", {:action => "moderate"}, :api => {:count => changed})
  end

  def upload_problem
  end

  def upload
    @deleted_posts = FlaggedPostDetail.new_deleted_posts(@current_user)
#    redirect_to :action => "upload_problem"
#    return

#    if params[:url]
#      @post = Post.find(:first, :conditions => ["source = ?", params[:url]])
#    end
    
    if @post.nil?
      @post = Post.new
    end
  end

  def create
#    respond_to_error("Uploads temporarily disabled due to Amazon S3 issues", :action => "upload_problem")
#    return

    if @current_user.is_member_or_lower? && Post.count(:conditions => ["user_id = ? AND created_at > ? ", @current_user.id, 1.day.ago]) >= CONFIG["member_post_limit"]
      respond_to_error("Daily limit exceeded", {:action => "index"}, :status => 421)
      return
    end

    if @current_user.is_privileged_or_higher?
      status = "active"
    else
      status = "pending"
    end

    @post = Post.create(params[:post].merge(:updater_user_id => @current_user.id, :updater_ip_addr => request.remote_ip, :user_id => @current_user.id, :ip_addr => request.remote_ip, :status => status))

    if @post.errors.empty?
      if params[:md5] && @post.md5 != params[:md5].downcase
        @post.destroy
        respond_to_error("MD5 mismatch", {:action => "upload"}, :status => 420)
      else
        if CONFIG["dupe_check_on_upload"] && @post.image? && @post.parent_id.nil?
          if params[:format] == "xml" || params[:format] == "json"
            options = { :services => SimilarImages.get_services("local"), :type => :post, :source => @post }

            res = SimilarImages.similar_images(options) 
            if not res[:posts].empty?
              @post.tags = @post.tags + " possible_duplicate"
              @post.save!
            end
          end

          respond_to_success("Post uploaded", {:controller => "post", :action => "similar", :id => @post.id, :initial => 1}, :api => {:post_id => @post.id, :location => url_for(:controller => "post", :action => "similar", :id => @post.id, :initial => 1)})
        else
          respond_to_success("Post uploaded", {:controller => "post", :action => "show", :id => @post.id, :tag_title => @post.tag_title}, :api => {:post_id => @post.id, :location => url_for(:controller => "post", :action => "show", :id => @post.id)})
        end
      end
    elsif @post.errors.invalid?(:md5)
      p = Post.find_by_md5(@post.md5)

      update = { :tags => p.cached_tags + " " + params[:post][:tags], :updater_user_id => session[:user_id], :updater_ip_addr => request.remote_ip }
      update[:source] = @post.source if p.source.blank? && !@post.source.blank?
      p.update_attributes(update)

      respond_to_error("Post already exists", {:controller => "post", :action => "show", :id => p.id, :tag_title => @post.tag_title}, :api => {:location => url_for(:controller => "post", :action => "show", :id => p.id)}, :status => 423)
    else
      respond_to_error(@post, :action => "upload")
    end
  end

  def moderate
    if request.post?
      Post.transaction do
        if params[:ids]
          params[:ids].keys.each do |post_id|
            if params[:commit] == "Approve"
              post = Post.find(post_id)
              post.approve!(@current_user.id)
            elsif params[:commit] == "Delete"
              Post.destroy_with_reason(post_id, params[:reason] || params[:reason2], @current_user)
            end
          end
        end
      end

      if params[:commit] == "Approve"
        respond_to_success("Post approved", {:action => "moderate"})
      elsif params[:commit] == "Delete"
        respond_to_success("Post deleted", {:action => "moderate"})
      end
    else
      if params[:query]
        @pending_posts = Post.find_by_sql(Post.generate_sql(params[:query], :pending => true, :order => "id desc"))
        @flagged_posts = Post.find_by_sql(Post.generate_sql(params[:query], :flagged => true, :order => "id desc"))
      else
        @pending_posts = Post.find(:all, :conditions => "status = 'pending'", :order => "id desc")
        @flagged_posts= Post.find(:all, :conditions => "status = 'flagged'", :order => "id desc")
      end
    end
  end

  def update
    @post = Post.find(params[:id])
    user_id = @current_user.id

    if @post.update_attributes(params[:post].merge(:updater_user_id => user_id, :updater_ip_addr => request.remote_ip))
      # Reload the post to send the new status back; not all changes will be reflected in
      # @post due to after_save changes.
      @post.reload
      respond_to_success("Post updated", {:action => "show", :id => @post.id, :tag_title => @post.tag_title}, :api => {:post => @post})
    else
      respond_to_error(@post, :action => "show", :id => params[:id])
    end
  end

  def update_batch
    user_id = @current_user.id

    ids = {}
    params["post"].each { |post|
      post_id = post[:id]
      post.delete(:id)
      @post = Post.find(post_id)
      ids[@post.id] = true

      # If an entry has only an ID, it was just included in the list to receive changes to
      # a post without changing it (for example, to receive the parent's data after reparenting
      # a post under it).
      next if post.empty?

      old_parent_id = @post.parent_id

      if @post.update_attributes(post.merge(:updater_user_id => user_id, :updater_ip_addr => request.remote_ip))
        # Reload the post to send the new status back; not all changes will be reflected in
        # @post due to after_save changes.
        @post.reload
      end

      if @post.parent_id != old_parent_id
        ids[@post.parent_id] = true if @post.parent_id
        ids[old_parent_id] = true if old_parent_id
      end
    }

    # Updates to one post may affect others, so only generate the return list after we've already
    # updated everything.
    ret = Post.find_by_sql(["SELECT * FROM posts WHERE id IN (?)", ids.map { |id, t| id }])

    respond_to_success("Post updated", {:action => "show", :id => @post.id, :tag_title => @post.tag_title}, :api => {:posts => ret})
  end

  def delete
    @post = Post.find(params[:id])
    
    if @post && @post.parent_id
      @post_parent = Post.find(@post.parent_id)
    end
  end
  
  def destroy
    if params[:commit] == "Cancel"
      redirect_to :action => "show", :id => params[:id]
      return
    end
  
    @post = Post.find(params[:id])

    if @post.can_user_delete?(@current_user)
      if @post.status == "deleted"
        @post.delete_from_database
      else
        Post.destroy_with_reason(@post.id, params[:reason], @current_user)
      end

      respond_to_success("Post deleted", :action => "index")
    else
      access_denied()
    end
  end
  
  def deleted_index
    if !@current_user.is_anonymous? && params[:user_id] && params[:user_id].to_i == @current_user.id
      @current_user.update_attribute(:last_deleted_post_seen_at, Time.now)
    end

    if params[:user_id]
      @posts = Post.paginate(:per_page => 25, :order => "flagged_post_details.created_at DESC", :joins => "JOIN flagged_post_details ON flagged_post_details.post_id = posts.id", :select => "flagged_post_details.reason, posts.cached_tags, posts.id, posts.user_id", :conditions => ["posts.status = 'deleted' AND posts.user_id = ? ", params[:user_id]], :page => params[:page])
    else
      @posts = Post.paginate(:per_page => 25, :order => "flagged_post_details.created_at DESC", :joins => "JOIN flagged_post_details ON flagged_post_details.post_id = posts.id", :select => "flagged_post_details.reason, posts.cached_tags, posts.id, posts.user_id", :conditions => ["posts.status = 'deleted'"], :page => params[:page])
    end
  end

  def acknowledge_new_deleted_posts
    @current_user.update_attribute(:last_deleted_post_seen_at, Time.now) if !@current_user.is_anonymous?
    respond_to_success("Success", {})
  end

  def index
    tags = params[:tags].to_s
    split_tags = QueryParser.parse(tags)
    page = params[:page].to_i
    
    if @current_user.is_member_or_lower? && split_tags.size > 2
      respond_to_error("You can only search up to two tags at once with a basic account", :action => "index")
      return
    elsif split_tags.size > 6
      respond_to_error("You can only search up to six tags at once", :action => "index")
      return
    end
    
    q = Tag.parse_query(tags)

    limit = params[:limit].to_i if params.has_key?(:limit)
    limit ||= q[:limit].to_i if q.has_key?(:limit)
    limit ||= 16
    limit = 1000 if limit > 1000

    count = 0

    begin
      count = Post.fast_count(tags)
    rescue => x
      respond_to_error("Error: #{x}", :action => "index")
      return
    end

    set_title "/" + tags.tr("_", " ")

    if count < 16 && split_tags.size == 1
      @tag_suggestions = Tag.find_suggestions(tags)
    end
    
    @ambiguous_tags = Tag.select_ambiguous(split_tags)
    
    @posts = WillPaginate::Collection.new(page, limit, count)
    offset = @posts.offset
    posts_to_load = @posts.per_page * 2

    # If we're not on the first page, load the previous page for prefetching.  Prefetching
    # the previous page when the user is scanning forward should be free, since it'll already
    # be in cache, so this makes scanning the index from back to front as responsive as from
    # front to back.
    if page && page > 1 then
      offset -= @posts.per_page
      posts_to_load += @posts.per_page
    end

    @showing_holds_only = q.has_key?(:show_holds_only) && q[:show_holds_only]

    from_api = (params[:format] == "json" || params[:format] == "xml")
    results = Post.find_by_sql(Post.generate_sql(q, :original_query => tags, :from_api => from_api, :order => "p.id DESC", :offset => offset, :limit => @posts.per_page * 3))
    @preload = []
    if page && page > 1 then
      @preload = results[0, limit] || []
      results = results[limit..-1] || []
    end
    @posts.replace(results[0..limit-1])
    @preload += results[limit..-1] || []

    respond_to do |fmt|
      fmt.html do        
        if split_tags.any?
          @tags = Tag.parse_query(tags)
        else
          @tags = Cache.get("$poptags", 1.hour) do
            {:include => Tag.count_by_period(1.day.ago, Time.now, :limit => 25, :exclude_types => CONFIG["exclude_from_tag_sidebar"])}
          end
        end
      end
      fmt.xml do
        render :layout => false
      end
      fmt.json {render :json => @posts.to_json}
    end
  end

  def atom
    # We get a lot of bogus "/post/atom.feed" requests that spam our error logs.  Make sure
    # we only try to format atom.xml.
    if not params[:format].nil? then
      # If we don't change the format, it tries to render "404.feed".
      params[:format] = "html"
      raise ActiveRecord::RecordNotFound
    end

    @posts = Post.find_by_sql(Post.generate_sql(params[:tags], :limit => 20, :order => "p.id DESC"))
    headers["Content-Type"] = "application/atom+xml"
    render :layout => false
  end

  def piclens
    @posts = WillPaginate::Collection.create(params[:page], 16, Post.fast_count(params[:tags])) do |pager|
      pager.replace(Post.find_by_sql(Post.generate_sql(params[:tags], :order => "p.id DESC", :offset => pager.offset, :limit => pager.per_page)))
    end
    
    headers["Content-Type"] = "application/rss+xml"
    render :layout => false
  end

  def show
    begin
      if params[:md5]
        @post = Post.find_by_md5(params[:md5].downcase) || raise(ActiveRecord::RecordNotFound)
      else
        @post = Post.find(params[:id])
      end
      
      if !@current_user.is_anonymous? && @post
        @vote = PostVotes.find_by_ids(@current_user.id, @post.id).score rescue 0
      end

      @pools = Pool.find(:all, :joins => "JOIN pools_posts ON pools_posts.pool_id = pools.id", :conditions => "pools_posts.post_id = #{@post.id} AND (active = true OR master_id IS NOT NULL)", :order => "pools.name", :select => "pools.name, pools.id")
      @tags = {:include => @post.cached_tags.split(/ /)}
      @include_tag_reverse_aliases = true
      set_title @post.title_tags.tr("_", " ")
    rescue ActiveRecord::RecordNotFound
      render :action => "show_empty", :status => 404
    end
  end

  def view
    redirect_to :action=>"show", :id=>params[:id]
  end

  def popular_recent
    case params[:period]
    when "1w"
      @period_name = "last week"
      period = 1.week
    when "1m"
      @period_name = "last month"
      period = 1.month
    when "1y"
      @period_name = "last year"
      period = 1.year
    else
      params[:period] = "1d"
      @period_name = "last 24 hours"
      period = 1.day
    end

    @params = params
    @end = Time.now
    @start = @end - period
    @previous = @start - period

    set_title "Exploring %s" % @period_name

    @posts = Post.find(:all, :conditions => ["status <> 'deleted' AND posts.index_timestamp >= ? AND posts.index_timestamp <= ? ", @start, @end], :order => "score DESC", :limit => 20)

    respond_to_list("posts")
  end

  def popular_by_day
    if params[:year] && params[:month] && params[:day]
      @day = Time.gm(params[:year].to_i, params[:month], params[:day])
    else
      @day = Time.new.getgm.at_beginning_of_day
    end

    set_title "Exploring #{@day.year}/#{@day.month}/#{@day.day}"

    @posts = Post.find(:all, :conditions => ["posts.created_at >= ? AND posts.created_at <= ? ", @day, @day.tomorrow], :order => "score DESC", :limit => 20)

    respond_to_list("posts")
  end

  def popular_by_week
    if params[:year] && params[:month] && params[:day]
      @start = Time.gm(params[:year].to_i, params[:month], params[:day]).beginning_of_week
    else
      @start = Time.new.getgm.beginning_of_week
    end

    @end = @start.next_week

    set_title "Exploring #{@start.year}/#{@start.month}/#{@start.day} - #{@end.year}/#{@end.month}/#{@end.day}"

    @posts = Post.find(:all, :conditions => ["posts.created_at >= ? AND posts.created_at < ? ", @start, @end], :order => "score DESC", :limit => 20)

    respond_to_list("posts")
  end

  def popular_by_month
    if params[:year] && params[:month]
      @start = Time.gm(params[:year].to_i, params[:month], 1)
    else
      @start = Time.new.getgm.beginning_of_month
    end

    @end = @start.next_month

    set_title "Exploring #{@start.year}/#{@start.month}"

    @posts = Post.find(:all, :conditions => ["posts.created_at >= ? AND posts.created_at < ? ", @start, @end], :order => "score DESC", :limit => 20)

    respond_to_list("posts")
  end

  def revert_tags
    user_id = @current_user.id
    @post = Post.find(params[:id])
    @post.update_attributes(:tags => PostTagHistory.find(params[:history_id].to_i).tags, :updater_user_id => user_id, :updater_ip_addr => request.remote_ip)

    respond_to_success("Tags reverted", :action => "show", :id => @post.id, :tag_title => @post.tag_title)
  end

  def vote
    p = Post.find(params[:id])
    score = params[:score].to_i
    
    if !@current_user.is_mod_or_higher? && score < 0 || score > 3
      respond_to_error("Invalid score", {:action => "show", :id => params[:id], :tag_title => p.tag_title}, :status => 424)
      return
    end

    options = {}
    if p.vote!(score, @current_user, request.remote_ip, options)
      voted_by = p.voted_by
      voted_by.each_key { |vote|
        users = voted_by[vote]
        users.map! { |user|
          { :name => user.pretty_name, :id => user.id }
        }
      }
      respond_to_success("Vote saved", {:action => "show", :id => params[:id], :tag_title => p.tag_title}, :api => {:vote => score, :score => p.score, :post_id => p.id, :votes => voted_by })
    else
      respond_to_error("Already voted", {:action => "show", :id => params[:id], :tag_title => p.tag_title}, :status => 423)
    end
  end

  def flag
    post = Post.find(params[:id])
    if post.status != "active"
      respond_to_error("Can only flag active posts", :action => "show", :id => params[:id])
      return
    end

    post.flag!(params[:reason], @current_user.id)
    respond_to_success("Post flagged", :action => "show", :id => params[:id])
  end
  
  def random
    max_id = Post.maximum(:id)
    
    10.times do
      post = Post.find(:first, :conditions => ["id = ? AND status <> 'deleted'", rand(max_id) + 1])

      if post != nil && post.can_be_seen_by?(@current_user)
        redirect_to :action => "show", :id => post.id, :tag_title => post.tag_title
        return
      end
    end
    
    flash[:notice] = "Couldn't find a post in 10 tries. Try again."
    redirect_to :action => "index"
  end

  def similar
    @params = params
    if params[:file].blank? then params.delete(:file) end
    if params[:url].blank? then params.delete(:url) end
    if params[:id].blank? then params.delete(:id) end
    if params[:search_id].blank? then params.delete(:search_id) end
    if params[:services].blank? then params.delete(:services) end
    if params[:threshold].blank? then params.delete(:threshold) end
    if params[:forcegray].blank? || params[:forcegray] == "0" then params.delete(:forcegray) end
    if params[:initial] == "0" then params.delete(:initial) end
    if not SimilarImages.valid_saved_search(params[:search_id]) then params.delete(:search_id) end
    params[:width] = params[:width].to_i if params[:width]
    params[:height] = params[:height].to_i if params[:height]

    @initial = params[:initial]
    if @initial && !params[:services]
      params[:services] = "local"
    end

    @services = SimilarImages.get_services(params[:services])
    if params[:id]
      begin
        @compared_post = Post.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render :status => 404
        return;
      end
    end

    if @compared_post && @compared_post.is_deleted?
      respond_to_error("Post deleted", :controller => "post", :action => "show", :id => params[:id], :tag_title => @compared_post.tag_title)
      return
    end

    # We can do these kinds of searches:
    #
    # File: Search from a specified file.  The image is saved locally with an ID, and sent
    # as a file to the search servers.
    #
    # URL: search from a remote URL.  The URL is downloaded, and then treated as a :file
    # search.  This way, changing options doesn't repeatedly download the remote image,
    # and it removes a layer of abstraction when an error happens during download
    # compared to having the search server download it.
    #
    # Post ID: Search from a post ID.  The preview image is sent as a URL.
    #
    # Search ID: Search using an image uploaded with a previous File search, using
    # the search MD5 created.  We're not allowed to repopulate filename fields in the
    # user's browser, so we can't re-submit the form as a file search when changing search
    # parameters.  Instead, we hide the search ID in the form, and use it to recall the
    # file from before.  These files are expired after a while; we check for expired files
    # when doing later searches, so we don't need a cron job.
    def search(params)
      options = params.merge({
        :services => @services,
      })

      # Check search_id first, so options links that include it will use it.  If the
      # user searches with the actual form, search_id will be cleared on submission.
      if params[:search_id] then
        file_path = SimilarImages.find_saved_search(params[:search_id])
        if file_path.nil?
          # The file was probably purged.  Delete :search_id before redirecting, so the
          # error doesn't loop.
          params.delete(:search_id)
          return { :errors => { :error => "Search expired" } }
        end
      elsif params[:url] || params[:file] then
        # Save the file locally.
        begin
          if params[:url] then
            search = Timeout::timeout(30) do
              Danbooru.http_get_streaming(params[:url]) do |res|
                SimilarImages.save_search do |f|
                  res.read_body do |block|
                    f.write(block)
                  end
                end
              end
            end
          else # file
            search = SimilarImages.save_search do |f|
              wrote = 0
              buf = ""
              while params[:file].read(1024*64, buf) do
                wrote += buf.length
                f.write(buf)
              end

              if wrote == 0 then
                return { :errors => { :error => "No file received" } }
              end
            end
          end
        rescue SocketError, URI::Error, SystemCallError, Danbooru::ResizeError => e
          return { :errors => { :error => "#{e}" } }
        rescue Timeout::Error => e
          return { :errors => { :error => "Download timed out" } }
        end

	file_path = search[:file_path]

        # Set :search_id in params for generated URLs that point back here.
	params[:search_id] = search[:search_id]

        # The :width and :height params specify the size of the original image, for display
        # in the results.  The user can specify them; if not specified, fill it in.
	params[:width] ||= search[:original_width]
	params[:height] ||= search[:original_height]
      elsif params[:id] then
        options[:source] = @compared_post
        options[:type] = :post
      end

      if params[:search_id] then
        options[:source] = File.open(file_path, 'rb')
        options[:source_filename] = params[:search_id]
        options[:source_thumb] = "/data/search/#{params[:search_id]}"
        options[:type] = :file
      end
      options[:width] = params[:width]
      options[:height] = params[:height]

      if options[:type] == :file
        SimilarImages.cull_old_searches
      end

      return SimilarImages.similar_images(options) 
    end

    unless params[:url].nil? and params[:id].nil? and params[:file].nil? and params[:search_id].nil? then
      res = search(params)

      @errors = res[:errors]
      @searched = true
      @search_id = res[:search_id]

      # Never pass :file on through generated URLs.
      params.delete(:file)
    else
      res = {}
      @errors = {}
      @searched = false
    end

    @posts = res[:posts]
    @similar = res

    respond_to do |fmt|
      fmt.html do
        if @initial=="1" && @posts.empty?
          flash.keep
          redirect_to :controller => "post", :action => "show", :id => params[:id], :tag_title => @compared_post.tag_title
          return
        end
        if @errors[:error]
          flash[:notice] = @errors[:error]
        end

        if @posts then
          @posts = res[:posts_external] + @posts
          @posts = @posts.sort { |a, b| res[:similarity][b] <=> res[:similarity][a] }

          # Add the original post to the start of the list.
          if res[:source]
            @posts = [ res[:source] ] + @posts
          else
            @posts = [ res[:external_source] ] + @posts
          end
        end
      end
      fmt.xml do
        if @errors[:error]
          respond_to_error(@errors[:error], {:action => "index"}, :status => 503)
          return
        end
        x = Builder::XmlMarkup.new(:indent => 2)
        x.instruct!
        render :xml => x.posts() {
         unless res[:errors].empty?
            res[:errors].map { |server, error|
              { :server=>server, :message=>error[:message], :services=>error[:services].join(",") }.to_xml(:root => "error", :builder => x, :skip_instruct => true)
            }
         end

          if res[:source]
           x.source() {
             res[:source].to_xml(:builder => x, :skip_instruct => true)
           }
          else
           x.source() {
             res[:external_source].to_xml(:builder => x, :skip_instruct => true)
           }
          end

          @posts.each { |e|
           x.similar(:similarity=>res[:similarity][e]) {
             e.to_xml(:builder => x, :skip_instruct => true)
           }
          }
          res[:posts_external].each { |e|
           x.similar(:similarity=>res[:similarity][e]) {
             e.to_xml(:builder => x, :skip_instruct => true)
           }
          }
        }
      end
    end
  end
  
  def undelete
    post = Post.find(params[:id])
    post.undelete!
    respond_to_success("Post was undeleted", :action => "show", :id => params[:id])
  end
  
  def exception
    raise "error"
  end
end
