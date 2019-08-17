# encoding: utf-8

class WikiController < ApplicationController
  layout "default"
  before_action :post_member_only, :only => [:update, :create, :edit, :revert]
  before_action :mod_only, :only => [:lock, :unlock, :destroy, :rename]
  helper :post

  def destroy
    page = WikiPage.find_page(params[:title])
    page.destroy
    respond_to_success("Page deleted", :action => "show", :title => params[:title])
  end

  def lock
    page = WikiPage.find_page(params[:title])
    page.lock!
    respond_to_success("Page locked", :action => "show", :title => params[:title])
  end

  def unlock
    page = WikiPage.find_page(params["title"])
    page.unlock!
    respond_to_success("Page unlocked", :action => "show", :title => params[:title])
  end

  def index
    @params = params # FIXME: what the hell is this

    @wiki_pages = WikiPage.all

    order =
      if params[:order] == "date"
        { :updated_at => :desc }
      else
        Arel.sql("LOWER(title)")
      end

    limit = params[:limit] || 25
    query = params[:query]

    if query.present?
      cond = \
        if query =~ /\Atitle:/
          ["title ILIKE ?", "%#{query[6..-1].to_escaped_for_sql_like}%"]
        else
          query = query.scan(/\S+/)
          ["text_search_index @@ PLAINTO_TSQUERY(?)", query.join(" & ")]
        end
      @wiki_pages = @wiki_pages.where cond
    end

    @wiki_pages = @wiki_pages.order(order).paginate :per_page => limit, :page => page_number

    respond_to_list("wiki_pages")
  end

  def preview
    render :inline => "<%= format_text(params[:body]) %>"
  end

  def add
    @wiki_page = WikiPage.new
    @wiki_page.title = params[:title] || "Title"
  end

  def create
    page = WikiPage.create(wiki_page_params.merge(:ip_addr => request.remote_ip, :user_id => @current_user.id))

    if page.errors.empty?
      respond_to_success("Page created", { :action => "show", :title => page.title }, :location => url_for(:action => "show", :title => page.title))
    else
      respond_to_error(page, :action => "index")
    end
  end

  def edit
    if params[:title].blank?
      render :plain => "no title specified"
    else
      @wiki_page = WikiPage.find_page(params[:title], params[:version])

      if @wiki_page.nil?
        redirect_to :action => "add", :title => params[:title]
      end
    end
  end

  def update
    @page = WikiPage.find_page(params[:title] || params[:wiki_page][:title])

    if @page.is_locked?
      respond_to_error("Page is locked", { :action => "show", :title => @page.title }, :status => 422)
    else
      if @page.update(wiki_page_params.merge(:ip_addr => request.remote_ip, :user_id => session[:user_id]))
        respond_to_success("Page updated", :action => "show", :title => @page.title)
      else
        respond_to_error(@page, :action => "show", :title => @page.title)
      end
    end
  end

  def show
    if params[:title].blank?
      render :plain => "no title specified"
      return
    end

    @title = params[:title]
    @page = WikiPage.find_page(params[:title], params[:version])
    @posts = Post
      .find_by_tag_join(params[:title])
      .where.not(:status => "deleted")
      .limit(8)
      .select { |x| x.can_be_seen_by?(@current_user) }
    @artist = Artist.find_by_name(params[:title])
    @tag = Tag.find_by_name(params[:title])

    respond_to do |format|
      format.html
    end
  end

  def revert
    @page = WikiPage.find_page(params[:title])

    if @page.is_locked?
      respond_to_error("Page is locked", { :action => "show", :title => params[:title] }, :status => 422)
    else
      @page.revert_to(params[:version])
      @page.ip_addr = request.remote_ip
      @page.user_id = @current_user.id

      if @page.save
        respond_to_success("Page reverted", :action => "show", :title => params[:title])
      else
        respond_to_error((@page.errors.full_messages.first rescue "Error reverting page"), :action => "show", :title => params[:title])
      end
    end
  end

  def recent_changes
    @wiki_pages = WikiPage.order(:updated_at => :desc)

    if params[:user_id]
      @wiki_pages = @wiki_pages.where(:user_id => params[:user_id])
    end

    @wiki_pages = @wiki_pages.paginate :per_page => (params[:per_page] || 25), :page => page_number

    respond_to_list("wiki_pages")
  end

  def history
    if params[:title]
      wiki = WikiPage.find_by_title(params[:title])
      wiki_id = wiki.id if wiki
    elsif params[:id]
      wiki_id = params[:id]
    end
    @wiki_pages = WikiPageVersion.where(:wiki_page_id => wiki_id).order(:version => :desc)

    respond_to_list("wiki_pages")
  end

  def diff
    if params[:redirect]
      redirect_to :action => "diff", :title => params[:title], :from => params[:from], :to => params[:to]
      return
    end

    if params[:title].blank? || params[:to].blank? || params[:from].blank?
      flash[:notice] = "No title was specificed"
      redirect_to :action => "index"
      return
    end

    @oldpage = WikiPage.find_page(params[:title], params[:from])
    unless @oldpage
      flash[:notice] = "Page with specified title does not exist"
      redirect_to :action => :index
      return
    end
    @difference = @oldpage.diff(params[:to])
  end

  def rename
    @wiki_page = WikiPage.find_page(params[:title])
  end

  private

  def wiki_page_params
    params.require(:wiki_page).permit(:title, :body)
  end
end
