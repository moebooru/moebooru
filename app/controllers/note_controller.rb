class NoteController < ApplicationController
  layout 'default', :only => [:index, :history, :search]
  before_filter :post_member_only, :only => [:destroy, :update, :revert]
  helper :post

  def search
    if params[:query]
      query = params[:query].scan(/\S+/).join(" & ")
      @notes = Note.paginate :order => "id asc", :per_page => 25, :conditions => ["text_search_index @@ plainto_tsquery(?)", query], :page => page_number

      respond_to_list("notes")
    end
  end

  def index
    if params[:post_id]
      @posts = Post.paginate :order => "last_noted_at DESC", :conditions => ["id = ?", params[:post_id]], :per_page => 100, :page => page_number
    else
      @posts = Post.paginate :order => "last_noted_at DESC", :conditions => "last_noted_at IS NOT NULL", :per_page => 16, :page => page_number
    end

    respond_to do |fmt|
      fmt.html
      fmt.xml {render :xml => @posts.map {|x| x.notes}.flatten.to_xml(:root => "notes")}
      fmt.json {render :json => @posts.map {|x| x.notes}.flatten.to_json}
    end
  end

  def history
    if params[:id]
      @notes = NoteVersion.paginate(:page => page_number, :per_page => 25, :order => "id DESC", :conditions => ["note_id = ?", params[:id].to_i])
    elsif params[:post_id]
      @notes = NoteVersion.paginate(:page => page_number, :per_page => 50, :order => "id DESC", :conditions => ["post_id = ?", params[:post_id].to_i])
    elsif params[:user_id]
      @notes = NoteVersion.paginate(:page => page_number, :per_page => 50, :order => "id DESC", :conditions => ["user_id = ?", params[:user_id].to_i])
    else
      @notes = NoteVersion.paginate(:page => page_number, :per_page => 25, :order => "id DESC")
    end

    respond_to_list("notes")
  end

  def revert
    note = Note.find(params[:id])

    if note.is_locked?
      respond_to_error("Post is locked", {:action => "history", :id => note.id}, :status => 422)
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
      respond_to_error("Post is locked", {:controller => "post", :action => "show", :id => note.post_id}, :status => 422)
      return
    end

    note.attributes = params[:note]
    note.user_id = @current_user.id
    note.ip_addr = request.remote_ip

    if note.save
      respond_to_success("Note updated", {:action => "index"}, :api => {:new_id => note.id, :old_id => params[:id].to_i, :formatted_body => ActionController::Base.helpers.sanitize(note.formatted_body)})
    else
      respond_to_error(note, :controller => "post", :action => "show", :id => note.post_id)
    end
  end
end
