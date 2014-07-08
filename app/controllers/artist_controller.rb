# encoding: utf-8

class ArtistController < ApplicationController
  layout "default"

  before_filter :post_member_only, :only => [:create, :update]
  before_filter :post_privileged_only, :only => [:destroy]
  helper :post, :wiki

  def preview
    render :inline => "<h4>Preview</h4><%= format_text(params[:artist][:notes]) %>"
  end

  def destroy
    @artist = Artist.find(params[:id])

    if request.post?
      if params[:commit] == "Yes"
        @artist.destroy
        respond_to_success("Artist deleted", :action => "index", :page => page_number)
      else
        redirect_to :action => "index", :page => page_number
      end
    end
  end

  def update
    if request.post?
      if params[:commit] == "Cancel"
        redirect_to :action => "show", :id => params[:id]
        return
      end

      artist = Artist.find(params[:id])
      artist.update_attributes(params[:artist].merge(:updater_ip_addr => request.remote_ip, :updater_id => @current_user.id))

      if artist.errors.empty?
        respond_to_success("Artist updated", :action => "show", :id => artist.id)
      else
        respond_to_error(artist, :action => "update", :id => artist.id)
      end
    else
      @artist = Artist.find(params["id"])
    end
  end

  def create
    if request.post?
      artist = Artist.create(params[:artist].merge(:updater_ip_addr => request.remote_ip, :updater_id => @current_user.id))

      if artist.errors.empty?
        respond_to_success("Artist created", :action => "show", :id => artist.id)
      else
        respond_to_error(artist, :action => "create", :alias_id => params[:alias_id])
      end
    else
      @artist = Artist.new

      if params[:name]
        @artist.name = params[:name]

        post = Post.has_any_tags(params[:name].to_s).where('source LIKE ?', 'http*'.to_escaped_for_sql_like).available.first
        unless post == nil || post.source.blank?
          @artist.urls = post.source
        end
      end

      if params[:alias_id]
        @artist.alias_id = params[:alias_id]
      end
    end
  end

  def index
    if params[:order] == "date"
      order = "updated_at DESC"
    else
      order = "name"
    end

    if params[:name]
      @artists = Artist.paginate Artist.generate_sql(params[:name]).merge(:per_page => 50, :page => page_number, :order => order)
    elsif params[:url]
      @artists = Artist.paginate Artist.generate_sql(params[:url]).merge(:per_page => 50, :page => page_number, :order => order)
    else
      @artists = Artist.paginate :order => order, :per_page => 25, :page => page_number
    end

    respond_to_list("artists")
  end

  def show
    if params[:name]
      @artist = Artist.find_by(name: params[:name])
    else
      @artist = Artist.find(params[:id])
    end

    if @artist.nil?
      redirect_to :action => "create", :name => params[:name]
    else
      redirect_to :controller => "wiki", :action => "show", :title => @artist.name
    end
  end
end
