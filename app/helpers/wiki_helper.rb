# encoding: utf-8
module WikiHelper
  def linked_from(to)
    links = to.find_pages_that_link_to_this.map do |page|
      link_to(h(page.pretty_title), :controller => "wiki", :action => "show", :title => page.title)
    end.join(", ")

    links.empty? ? "None" : links
  end

  # Generates content for "Changes" column on history page.
  # Not filtered, must return HTML-safe string.
  def page_change(w)
    if w.what_updated.empty?
      'No change'
    else
      w.what_updated.map do |c|
        case c
        when :initial
          'first version'
        when :body
          'content update'
        when :title
          "page rename (#{h w.title} ← #{h w.prev.title})"
        when :is_locked
          w.is_locked ? 'page lock' : 'page unlock'
        end
      end.join(', ').capitalize
    end
  end
end
