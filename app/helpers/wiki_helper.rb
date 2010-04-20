module WikiHelper
  def linked_from(to)
    links = to.find_pages_that_link_to_this.map do |page|
      link_to(h(page.pretty_title), :controller => "wiki", :action => "show", :title => page.title)
    end.join(", ")

    links.empty? ? "None" : links
  end
end
