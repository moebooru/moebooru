class NoteVersion < ActiveRecord::Base
  def to_xml(options = {})
    {:created_at => created_at, :updated_at => updated_at, :creator_id => user_id, :x => x, :y => y, :width => width, :height => height, :is_active => is_active, :post_id => post_id, :body => body, :version => version}.to_xml(options.merge(:root => "note_version"))
  end

  def to_json(*args)
    {:created_at => created_at, :updated_at => updated_at, :creator_id => user_id, :x => x, :y => y, :width => width, :height => height, :is_active => is_active, :post_id => post_id, :body => body, :version => version}.to_json(*args)
  end

  def author
    User.find_name(user_id)
  end
end
