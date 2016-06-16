class NoteController < ApplicationController
  layout "default", :only => [:index, :history, :search]
  before_action :post_member_only, :only => [:destroy, :update, :revert]
  helper :post

  def search
    if params[:query]
      query = params[:query].scan(/\S+/).join(" & ")
      @notes = Note.where("text_search_index @@ plainto_tsquery(?)", query).order(:id).paginate(:per_page => 25, :page => page_number)

      return respond_to_list("notes")
    end

    respond_to do |format|
      format.html
    end
  end

  def index
    @posts = Post.order :last_noted_at => :desc
    if params[:post_id]
      @posts = @posts.where :id => params[:post_id]
      per_page = 100
    else
      @posts = @posts.where.not :last_noted_at => nil
      per_page = 16
    end
    @posts = @posts.paginate :per_page => per_page, :page => page_number

    respond_to do |fmt|
      fmt.html
      fmt.xml { render :xml => @posts.map(&:notes).flatten.to_xml(:root => "notes") }
      fmt.json { render :json => @posts.map(&:notes).flatten.to_json }
    end
  end

  def history
    @notes = NoteVersion.order :id => :desc

    per_page = 25
    if params[:id]
      @notes = @notes.where(:note_id => params[:id])
    elsif params[:post_id]
      per_page = 50
      @notes = @notes.where(:post_id => params[:post_id])
    elsif params[:user_id]
      per_page = 50
      @notes = @notes.where(:user_id => params[:user_id])
    end
    @notes = @notes.paginate :page => page_number, :per_page => per_page

    respond_to_list("notes")
  end

  def revert
    note = Note.find(params[:id])

    if note.is_locked?
      respond_to_error("Post is locked", { :action => "history", :id => note.id }, :status => 422)
      return
    end

    note.revert_to(params[:version])
    note.ip_addr = request.remote_ip
    note.user_id = @current_user.id

    if note.save
      respond_to_success("Note reverted", :action => "history", :id => note.id)
    else
      render_error(note)
    end
  end

  def update
    if params[:note][:post_id]
      note = Note.new(:post_id => params[:note][:post_id])
    else
      note = Note.find(params[:id])
    end

    if note.is_locked?
      respond_to_error("Post is locked", { :controller => "post", :action => "show", :id => note.post_id }, :status => 422)
      return
    end

    note.attributes = note_params
    note.user_id = @current_user.id
    note.ip_addr = request.remote_ip

    if note.save
      respond_to_success("Note updated", { :action => "index" }, :api => { :new_id => note.id, :old_id => params[:id].to_i, :formatted_body => ActionController::Base.helpers.sanitize(note.formatted_body) })
    else
      respond_to_error(note, :controller => "post", :action => "show", :id => note.post_id)
    end
  end

  private

  def note_params
    params.require(:note).permit(:post_id, :x, :y, :width, :height, :body, :is_active)
  end
end
