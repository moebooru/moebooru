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
  # a is current
  # b is previous (or what's a compared to)
  def page_change(a, b)
    changes = a.diff(b)
    if changes.empty?
      "no change"
    else
      changes.map do |change|
        case change
        when :initial
          "first version"
        when :body
          "content update"
        when :title
          "page rename (#{h a.title} ← #{h b.title})"
        when :is_locked
          a.is_locked ? "page lock" : "page unlock"
        end
      end.join(", ")
    end
  end
end
