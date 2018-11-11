class WikiPageVersion < ApplicationRecord
  def author
    User.find_name(user_id)
  end

  def diff(target)
    what = []
    if target
      what += [:body] if body != target.body
      what += [:title] if title != target.title
      what += [:is_locked] if is_locked != target.is_locked
    end
    if version == 1
      what += [:initial]
    end
    what
  end

  def prev
    WikiPageVersion.first(:conditions => { :wiki_page_id => wiki_page_id, :version => version - 1 })
  end

  def pretty_title
    title.tr("_", " ")
  end

  def to_xml(options = {})
    { :id => id, :created_at => created_at, :updated_at => updated_at, :title => title, :body => body, :updater_id => user_id, :locked => is_locked, :version => version, :post_id => post_id }.to_xml(options.reverse_merge(:root => "wiki_page_version"))
  end

  def as_json(*args)
    { :id => id, :created_at => created_at, :updated_at => updated_at, :title => title, :body => body, :updater_id => user_id, :locked => is_locked, :version => version, :post_id => post_id }.as_json(*args)
  end
end
