class ForumController < ApplicationController
  layout "default"
  helper :avatar
  before_action :sanitize_id, :only => [:show]
  before_action :mod_only, :only => [:stick, :unstick, :lock, :unlock]
  before_action :member_only, :only => [:destroy, :update, :edit, :add, :mark_all_read, :preview]
  before_action :post_member_only, :only => [:create]

  def stick
    ForumPost.stick!(params[:id])
    flash[:notice] = "Topic stickied"
    redirect_to :action => "show", :id => params[:id]
  end

  def unstick
    ForumPost.unstick!(params[:id])
    flash[:notice] = "Topic unstickied"
    redirect_to :action => "show", :id => params[:id]
  end

  def preview
    if params[:forum_post]
      @preview = true
      forum_post = ForumPost.new(forum_post_params.merge(:creator_id => @current_user.id))
      forum_post.created_at = Time.now
      render :partial => "post", :locals => { :post => forum_post }
    else
      render :plain => ""
    end
  end

  def new
    @forum_post = ForumPost.new

    if params[:type] == "alias"
      @forum_post.title = "Tag Alias: "
      @forum_post.body = "Aliasing ___ to ___.\n\nReason: "
    elsif params[:type] == "impl"
      @forum_post.title = "Tag Implication: "
      @forum_post.body = "Implicating ___ to ___.\n\nReason: "
    end
  end

  def create
    @forum_post = ForumPost.create(forum_post_params.merge(:creator_id => @current_user.id))

    if @forum_post.errors.empty?
      if params[:forum_post][:parent_id].to_i == 0
        flash[:notice] = "Forum topic created"
        redirect_to :action => "show", :id => @forum_post.root_id
      else
        flash[:notice] = "Response posted"
        redirect_to :action => "show", :id => @forum_post.root_id, :page => (@forum_post.root.response_count / 30.0).ceil
      end
    else
      render_error(@forum_post)
    end
  end

  def add
  end

  def destroy
    @forum_post = ForumPost.find(params[:id])

    if @current_user.has_permission?(@forum_post, :creator_id)
      @forum_post.destroy
      flash[:notice] = "Post destroyed"

      if @forum_post.is_parent?
        redirect_to :action => "index"
      else
        redirect_to :action => "show", :id => @forum_post.root_id
      end
    else
      flash[:notice] = "Access denied"
      redirect_to :action => "show", :id => @forum_post.root_id
    end
  end

  def edit
    @forum_post = ForumPost.find(params[:id])

    unless @current_user.has_permission?(@forum_post, :creator_id)
      access_denied
    end
  end

  def update
    @forum_post = ForumPost.find(params[:id])

    unless @current_user.has_permission?(@forum_post, :creator_id)
      access_denied
      return
    end

    @forum_post.attributes = forum_post_params
    if @forum_post.save
      flash[:notice] = "Post updated"
      redirect_to :action => "show", :id => @forum_post.root_id, :page => (@forum_post.root.response_count / 30.0).ceil
    else
      render_error(@forum_post)
    end
  end

  def show
    @forum_post = ForumPost.find(params[:id])
    @children = @forum_post.children.order(:id).paginate :per_page => 30, :page => page_number

    if !@current_user.is_anonymous? && @current_user.last_forum_topic_read_at < @forum_post.updated_at
      @current_user.update_attribute(:last_forum_topic_read_at, @forum_post.updated_at)
    end

    respond_to_list("forum_post")
  end

  def index
    @forum_posts = ForumPost.includes(:updater, :creator).order(:is_sticky => :desc, :updated_at => :desc)
    if params[:parent_id]
      @forum_posts = @forum_posts.where(:parent_id => params[:parent_id]).paginate :per_page => 100, :page => page_number
    elsif params[:latest]
      @forum_posts = @forum_posts.latest
    else
      @forum_posts = @forum_posts.where(:parent_id => nil).paginate :per_page => 30, :page => page_number
    end

    respond_to_list("forum_posts")
  end

  def search
    @forum_posts = ForumPost.includes(:creator, :updater, :parent).order(:id => :desc)
    if params[:query]
      query = params[:query].scan(/\S+/).join(" & ")
      @forum_posts = @forum_posts.where("text_search_index @@ plainto_tsquery(?)", query).paginate :per_page => 30, :page => page_number
    else
      @forum_posts = @forum_posts.paginate :per_page => 30, :page => page_number
    end

    respond_to_list("forum_posts")
  end

  def lock
    ForumPost.lock!(params[:id])
    flash[:notice] = "Topic locked"
    redirect_to :action => "show", :id => params[:id]
  end

  def unlock
    ForumPost.unlock!(params[:id])
    flash[:notice] = "Topic unlocked"
    redirect_to :action => "show", :id => params[:id]
  end

  def mark_all_read
    @current_user.update_attribute(:last_forum_topic_read_at, Time.now)
    head :no_content
  end

  private

  def forum_post_params
    params.require(:forum_post).permit(:parent_id, :title, :body)
  end
end
