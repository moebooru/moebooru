class PoolController < ApplicationController
  layout "default"
  before_filter :member_only, :only => [:destroy, :update, :add_post, :remove_post, :import, :zip]
  before_filter :post_member_only, :only => [:create]
  before_filter :contributor_only, :only => [:copy, :transfer_metadata]
  helper :post
  
  def index
    set_title "Pools"

    options = { 
      :per_page => 20,
      :page => params[:page]
    }

    case params[:order]
    when "name":        options[:order] = "nat_sort(name) asc"
    when "date":        options[:order] = "created_at desc"
    when "updated":     options[:order] = "updated_at desc"
    when "date":        options[:order] = "id desc"
    else
      if params.has_key?(:query)
        options[:order] = "nat_sort(name) asc"
      else
        options[:order] = "created_at desc"
      end
    end

    if params[:query]
      conds = []
      cond_params = []
      value_index_query = []
      value_index_query << "(" + Post.geneate_sql_escape_helper(params[:query].split(/ /)).join(" & ") + ")"
      if value_index_query.any? then
        conds << """search_index @@ to_tsquery('pg_catalog.english', E'" + value_index_query.join(" & ") + "')"""
      end

      options[:conditions] = [conds.join(" AND "), *cond_params]
    end

    @pools = Pool.paginate options
    @samples = {}
    @pools.each { |p|
      post = p.get_sample
      if not post then next end
      @samples[p] = post
    }

    respond_to_list("pools")
  end
  
  def show
    if params[:samples] == "0" then params.delete(:samples) end

    @pool = Pool.find(params[:id], :include => [:pool_posts => :post])

    # We have the Pool.pool_posts association for this, but that doesn't seem to want to work...
    conds = ["pools_posts.pool_id = ?"]
    cond_params = params[:id]

    conds << "pools_posts.active"

    @posts = Post.paginate :per_page => 24, :order => "nat_sort(pools_posts.sequence), pools_posts.post_id", :joins => "JOIN pools_posts ON posts.id = pools_posts.post_id", :conditions => [conds.join(" AND "), *cond_params], :select => "posts.*, pools_posts.sequence AS sequence", :page => params[:page]

    set_title @pool.pretty_name
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
    end
  end

  def update
    @pool = Pool.find(params[:id])

    unless @pool.can_be_updated_by?(@current_user)
      access_denied()
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

      if not @new_pool.errors.empty? then
        respond_to_error(@new_pool, :action => "index")
        return
      end

      @old_pool.pool_posts.each { |pp|
        @new_pool.add_post(pp.post_id, :sequence => pp.sequence)
      }

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
        access_denied()
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
        respond_to_error("Post already exists", {:controller => "post", :action => "show", :id => params[:post_id]}, :status => 423)
      rescue Pool::AccessDeniedError
        access_denied()
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
      
      begin
        @pool.remove_post(params[:post_id], :user => @current_user)
      rescue Pool::AccessDeniedError
        access_denied()
        return
      end
      
      response.headers["X-Post-Id"] = params[:post_id]
      respond_to_success("Post removed", :controller => "post", :action => "show", :id => params[:post_id])
    else
      @pool = Pool.find(params[:pool_id])
      @post = Post.find(params[:post_id])
    end
  end
  
  def order
    @pool = Pool.find(params[:id])

    unless @pool.can_be_updated_by?(@current_user)
      access_denied()
      return
    end

    if request.post?
      PoolPost.transaction do
        params[:pool_post_sequence].each do |i, seq|
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
      access_denied()
      return
    end
    
    if request.post?
      if params[:posts].is_a?(Hash)
        ordered_posts = params[:posts].sort { |a,b| a[1]<=>b[1] }.map { |a| a[0] }

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
          @posts = Post.find_by_tags(params[:query], :order => "id desc", :limit => 500)
          @posts = @posts.select {|x| x.can_be_seen_by?(@current_user)}
        end
      end
    end
  end
  
  def select
    if @current_user.is_anonymous?
      @pools = Pool.find(:all, :order => "name", :conditions => "is_active = TRUE AND is_public = TRUE")
    else
      @pools = Pool.find(:all, :order => "name", :conditions => ["is_active = TRUE AND (is_public = TRUE OR user_id = ?)", @current_user.id])
    end
    
    render :layout => false
  end

  # Generate a ZIP control file for lighttpd, and redirect to the ZIP.
  if CONFIG["pool_zips"]
    def zip
      pool = Pool.find(params[:id], :include => [:pool_posts => :post])
      control_path = pool.get_zip_control_file_path(params)
      redirect_to pool.get_zip_url(control_path, params)
    end
  end

  def transfer_metadata
    @to = Pool.find(params[:to])

    if not params[:from] then
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
      min_posts = [from_posts.length, to_posts.length].max
      from_posts = from_posts.slice(0, min_posts)
      to_posts = to_posts.slice(0, min_posts)
    end

    @posts = []
    from_posts.each_index { |idx|
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
        tags << (from.is_shown_in_index ? "show":"hide")
      end

      if from.parent_id != to.id then
        tags << "child:%i" % from.id
      end

      data[:tags] = tags.join(" ")

      @posts << data
    }
  end
end
