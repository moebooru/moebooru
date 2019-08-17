# encoding: utf-8

class ArtistController < ApplicationController
  layout "default"

  before_action :post_member_only, :only => [:create, :update]
  before_action :post_privileged_only, :only => [:destroy]
  helper :post, :wiki

  def preview
    @notes = params.fetch(:artist, {})[:notes]
    respond_to do |format|
      format.html { render :layout => false }
    end
  end

  def destroy
    @artist = Artist.find(params[:id])
    page_number # fix params[:page]

    if request.post?
      if params[:commit] == "Yes"
        @artist.destroy
        respond_to_success("Artist deleted", :action => "index", :page => params[:page])
      else
        redirect_to :action => "index", :page => params[:page]
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
      artist.update(artist_params.merge(:updater_ip_addr => request.remote_ip, :updater_id => @current_user.id))

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
      artist = Artist.create(artist_params.merge(:updater_ip_addr => request.remote_ip, :updater_id => @current_user.id))

      if artist.errors.empty?
        respond_to_success("Artist created", :action => "show", :id => artist.id)
      else
        respond_to_error(artist, :action => "create", :alias_id => params[:alias_id])
      end
    else
      @artist = Artist.new

      if params[:name]
        @artist.name = params[:name]

        post = Post.has_any_tags(params[:name].to_s).where("source LIKE ?", "http*".to_escaped_for_sql_like).available.first
        unless post.nil? || post.source.blank?
          @artist.urls = post.source
        end
      end

      if params[:alias_id]
        @artist.alias_id = params[:alias_id]
      end
    end
  end

  def index
    @artists = Artist.order(params[:order] == "date" ? { :updated_at => :desc } : :name)

    per_page = 50
    if params[:name]
      @artists = @artists.where "name LIKE ?", "#{params[:name].to_escaped_for_sql_like}%"
    elsif params[:url]
      @artists = @artists.where :id => Artist.find_all_by_url(params[:url]).map(&:id)
    else
      per_page = 25
    end

    @artists = @artists.paginate :per_page => per_page, :page => page_number

    respond_to_list("artists")
  end

  def show
    if params[:name]
      @artist = Artist.find_by(:name => params[:name])
    else
      @artist = Artist.find(params[:id])
    end

    if @artist.nil?
      redirect_to :action => "create", :name => params[:name]
    else
      redirect_to :controller => "wiki", :action => "show", :title => @artist.name
    end
  end

  private

  def artist_params
    params.require(:artist).permit(:name, :alias_name, :alias_names, :member_names, :urls, :notes)
  end
end
