class WikiPageVersion < ActiveRecord::Base
  def author
    return User.find_name(self.user_id)
  end

  def pretty_title
    self.title.tr("_", " ")
  end

  def to_xml(options = {})
    {:id => id, :created_at => created_at, :updated_at => updated_at, :title => title, :body => body, :updater_id => user_id, :locked => is_locked, :version => version, :post_id => post_id}.to_xml(options.merge(:root => "wiki_page_version"))
  end

  def to_json(*args)
    {:id => id, :created_at => created_at, :updated_at => updated_at, :title => title, :body => body, :updater_id => user_id, :locked => is_locked, :version => version, :post_id => post_id}.to_json(*args)
  end
end
