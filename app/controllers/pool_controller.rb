class PoolController < ApplicationController
  layout "default"
  before_action :member_only, :only => [:destroy, :update, :add_post, :remove_post, :import, :zip]
  before_action :post_member_only, :only => [:create]
  before_action :contributor_only, :only => [:copy, :transfer_metadata]
  helper :post

  def index
    options = {
      :per_page => 20,
      :page => page_number
    }

    order = params[:order]

    conds = []
    cond_params = []

    search_tokens = []
    if params[:query]
      begin
        query = params[:query].shellsplit
      # Will raise error if not a valid shell-quoted string (unbalanced quotes).
      # Use plain split instead.
      rescue ArgumentError
        query = params[:query].split
      end

      query.each do |token|
        if token =~ /^(order|limit|posts):(.+)$/
          if Regexp.last_match[1] == "order"
            order = Regexp.last_match[2]
          elsif Regexp.last_match[1] == "limit"
            options[:per_page] = Regexp.last_match[2].to_i
            options[:per_page] = [options[:per_page], 100].min
          elsif Regexp.last_match[1] == "posts"
            Post.generate_sql_range_helper(Tag.parse_helper(Regexp.last_match[2]), "post_count", conds, cond_params)
          end
        else
          search_tokens << token
        end
      end
    end

    unless search_tokens.empty? then
      value_index_query = "(" + Array(search_tokens).map { |t| t.to_escaped_for_tsquery }.join(" & ") + ")"
      conds << "search_index @@ to_tsquery('pg_catalog.english', ?)"
      cond_params << value_index_query

      # If a search keyword contains spaces, then it was quoted in the search query
      # and we should only match adjacent words.  tsquery won't do this for us; we need
      # to filter results where the words aren't adjacent.
      #
      # This has a side-effect: any stopwords, stemming, parsing, etc. rules performed
      # by to_tsquery won't be done here.  We need to perform the same processing as
      # is used to generate search_index.  We don't perform all of the stemming rules, so
      # although "jump" may match "jumping", "jump beans" won't match "jumping beans" because
      # we'll filter it out.
      #
      # This also doesn't perform tokenization, so some obscure cases won't match perfectly;
      # for example, "abc def" will match "xxxabc def abc" when it probably shouldn't.  Doing
      # this more correctly requires Postgresql support that doesn't exist right now.
      query.each do |q|
        # Don't do this if there are no spaces in the query, so we don't turn off tsquery
        # parsing when we don't need to.
        next unless q.include?(" ")
        conds << "(position(LOWER(?) IN LOWER(replace_underscores(name))) > 0 OR position(LOWER(?) IN LOWER(description)) > 0)"
        cond_params << q
        cond_params << q
      end
    end

    options[:conditions] = [conds.join(" AND "), *cond_params]

    if order.nil? then
      if search_tokens.empty?
        order = "date"
      else
        order = "name"
      end
    end

    case order
      when "name" then options[:order] = "nat_sort(name) asc"
      when "date" then options[:order] = "created_at desc"
      when "updated" then options[:order] = "updated_at desc"
      when "id" then options[:order] = "id desc"
      else options[:order] = "created_at desc"
    end

    @pools = Pool.paginate options
    @samples = {}
    @pools.each do |p|
      post = p.get_sample
      unless post then next end
      @samples[p] = post
    end

    respond_to_list("pools", :atom => true)
  end

  def show
    if params[:samples] == "0" then params.delete(:samples) end

    begin
      @pool = Pool.find(params[:id].to_i, :include => [:pool_posts => :post])
    rescue
      flash[:notice] = t("c.pool.not_found", :id => params[:id].to_i)
      redirect_to :action => :index
      return
    end

    @browse_mode = @current_user.pool_browse_mode

    q = Tag.parse_query("")
    q[:pool] = params[:id].to_i
    q[:show_deleted_only] = false
    if @browse_mode == 1 then
      q[:limit] = 1000
    else
      q[:limit] = 24
    end

    count = Post.count_by_sql(Post.generate_sql(q, :from_api => true, :count => true))

    page = page_number.to_i > 0 ? page_number.to_i : 1
    @posts = WillPaginate::Collection.new(page, q[:limit], count)

    sql = Post.generate_sql(q, :from_api => true, :offset => @posts.offset, :limit => @posts.per_page)
    @posts.replace(Post.find_by_sql(sql))

    respond_to do |fmt|
      fmt.html
      fmt.xml do
        builder = Builder::XmlMarkup.new(:indent => 2)
        builder.instruct!

        xml = @pool.to_xml(:builder => builder, :skip_instruct => true) do
          builder.posts do
            @posts.each do |post|
              post.to_xml(:builder => builder, :skip_instruct => true)
            end
          end
        end
        render :xml => xml
      end
      fmt.json
    end
  end

  def update
    @pool = Pool.find(params[:id])

    unless @pool.can_be_updated_by?(@current_user)
      access_denied
      return
    end

    if request.post?
      @pool.update_attributes(params[:pool])
      respond_to_success("Pool updated", :action => "show", :id => params[:id])
    end
  end

  def create
    if request.post?
      @pool = Pool.create(params[:pool].merge(:user_id => @current_user.id))

      if @pool.errors.empty?
        respond_to_success("Pool created", :action => "show", :id => @pool.id)
      else
        respond_to_error(@pool, :action => "index")
      end
    else
      @pool = Pool.new(:user_id => @current_user.id)
    end
  end

  def copy
    @old_pool = Pool.find_by_id(params[:id])

    name = params[:name] || "#{@old_pool.name} (copy)"
    @new_pool = Pool.new(:user_id => @current_user.id, :name => name, :description => @old_pool.description)

    if request.post?
      @new_pool.save

      unless @new_pool.errors.empty? then
        respond_to_error(@new_pool, :action => "index")
        return
      end

      @old_pool.pool_posts.each do |pp|
        @new_pool.add_post(pp.post_id, :sequence => pp.sequence)
      end

      respond_to_success("Pool created", :action => "show", :id => @new_pool.id)
    end
  end

  def destroy
    @pool = Pool.find(params[:id])

    if request.post?
      if @pool.can_be_updated_by?(@current_user)
        @pool.destroy
        respond_to_success("Pool deleted", :action => "index")
      else
        access_denied
      end
    end
  end

  def add_post
    if request.post?
      @pool = Pool.find(params[:pool_id])
      session[:last_pool_id] = @pool.id

      if params[:pool] && !params[:pool][:sequence].blank?
        sequence = params[:pool][:sequence]
      else
        sequence = nil
      end

      begin
        @pool.add_post(params[:post_id], :sequence => sequence, :user => @current_user)
        respond_to_success("Post added", :controller => "post", :action => "show", :id => params[:post_id])
      rescue Pool::PostAlreadyExistsError
        respond_to_error("Post already exists", { :controller => "post", :action => "show", :id => params[:post_id] }, :status => 423)
      rescue Pool::AccessDeniedError
        access_denied
      rescue Exception => x
        respond_to_error(x.class, :controller => "post", :action => "show", :id => params[:post_id])
      end
    else
      if @current_user.is_anonymous?
        @pools = Pool.find(:all, :order => "name", :conditions => "is_active = TRUE AND is_public = TRUE")
      else
        @pools = Pool.find(:all, :order => "name", :conditions => ["is_active = TRUE AND (is_public = TRUE OR user_id = ?)", @current_user.id])
      end

      @post = Post.find(params[:post_id])
    end
  end

  def remove_post
    if request.post?
      @pool = Pool.find(params[:pool_id])
      post = Post.find(params[:post_id])

      begin
        @pool.remove_post(params[:post_id], :user => @current_user)
      rescue Pool::AccessDeniedError
        access_denied
        return
      end

      api_data = Post.batch_api_data([post])

      response.headers["X-Post-Id"] = params[:post_id]
      respond_to_success("Post removed", { :controller => "post", :action => "show", :id => params[:post_id] }, :api => api_data)
    else
      @pool = Pool.find(params[:pool_id])
      @post = Post.find(params[:post_id])
    end
  end

  def order
    @pool = Pool.find(params[:id])

    unless @pool.can_be_updated_by?(@current_user)
      access_denied
      return
    end

    if request.post?
      PoolPost.transaction do
        params.fetch(:pool_post_sequence, []).each do |i, seq|
          PoolPost.update(i, :sequence => seq)
        end

        @pool.reload
        @pool.update_pool_links
      end

      flash[:notice] = "Ordering updated"
      redirect_to :action => "show", :id => params[:id]
    else
      @pool_posts = @pool.pool_posts
    end
  end

  def import
    @pool = Pool.find(params[:id])

    unless @pool.can_be_updated_by?(@current_user)
      access_denied
      return
    end

    if request.post?
      if params[:posts].is_a?(Hash)
        ordered_posts = params[:posts].sort { |a, b| a[1] <=> b[1] }.map { |a| a[0] }

        PoolPost.transaction do
          ordered_posts.each do |post_id|
            begin
              @pool.add_post(post_id, :skip_update_pool_links => true)
            rescue Pool::PostAlreadyExistsError
              # ignore
            end
          end
          @pool.update_pool_links
        end
      end

      redirect_to :action => "show", :id => @pool.id
    else
      respond_to do |fmt|
        fmt.html
        fmt.js do
          @posts = Post.find_by_tags(params[:query], :limit => 500)
          @posts = @posts.select { |x| x.can_be_seen_by?(@current_user) }
        end
      end
    end
  end

  def select
    @post_id = params[:post_id].to_i
    if @current_user.is_anonymous?
      @pools = Pool.find(:all, :order => "name", :conditions => "is_active = TRUE AND is_public = TRUE")
    else
      @pools = Pool.find(:all, :order => "name", :conditions => ["is_active = TRUE AND (is_public = TRUE OR user_id = ?)", @current_user.id])
    end

    render :layout => false
  end

  # Generate a ZIP control file for nginx, and redirect to the ZIP.
  if CONFIG["pool_zips"]
    def zip
      # FIXME: should use the correct mime type instead of this hackery.
      Rack::MiniProfiler.deauthorize_request if Rails.env.development?
      pool = Pool.find(params[:id], :include => [:pool_posts => :post])
      @pool_zip = pool.get_zip_data(params)
      headers["X-Archive-Files"] = "zip"
      render :layout => false
    end
  end

  def transfer_metadata
    @to = Pool.find(params[:to])

    unless params[:from] then
      @from = nil
      return
    end

    @from = Pool.find(params[:from])

    from_posts = @from.pool_posts
    to_posts = @to.pool_posts

    if from_posts.length == to_posts.length then
      @truncated = false
    else
      @truncated = true
      min_posts = [from_posts.length, to_posts.length].min
      from_posts = from_posts.slice(0, min_posts)
      to_posts = to_posts.slice(0, min_posts)
    end

    @posts = []
    from_posts.each_index do |idx|
      data = {}
      from = from_posts[idx].post
      to = to_posts[idx].post
      data[:from] = from
      data[:to] = to

      from_tags = from.tags.split(" ")
      to_tags = to.tags.split(" ")

      tags = []
      tags.concat(from_tags)

      if from.rating != to.rating then
        tags << "rating:%s" % to.rating
      end

      if from.is_shown_in_index != to.is_shown_in_index then
        tags << (from.is_shown_in_index ? "show" : "hide")
      end

      if from.parent_id != to.id then
        tags << "child:%i" % from.id
      end

      data[:tags] = tags.join(" ")

      @posts << data
    end
  end
end
