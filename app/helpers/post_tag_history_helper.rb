module PostTagHistoryHelper
  def tag_list(tags, options = {})
    return "" if tags.blank?
    prefix = options[:prefix] || ""
    obsolete = options[:obsolete] || []

    html = ""

    # tags contains versioned metatags; split these out.
    metatags, tags = tags.partition {|x| x=~ /^(?:rating):/}
    metatags.each do |name|
      obsolete_tag = ([name] & obsolete).empty? ?  "":" obsolete-tag-change"
      html << %{<span class="tag-type-meta#{obsolete_tag}">}

      html << %{#{prefix}<a href="/post/index?tags=#{u(name)}">#{h(name)}</a> }
      html << '</span>'
    end

    tags = Tag.find(:all, :conditions => ["name in (?)", tags], :select => "name").inject([]) {|all, x| all << x.name; all}.to_a.sort {|a, b| a <=> b}

    tags.each do |name|
      name ||= "UNKNOWN"

      tag_type = Tag.type_name(name)

      obsolete_tag = ([name] & obsolete).empty? ?  "":" obsolete-tag-change"
      html << %{<span class="tag-type-#{tag_type}#{obsolete_tag}">}

      html << %{#{prefix}<a href="/post/index?tags=#{u(name)}">#{h(name)}</a> }
      html << '</span>'
    end

    return html
  end
end
