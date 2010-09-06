#!/usr/bin/env ruby

require 'cgi'

module DText
  def parse_inline(str)
    str = CGI.escapeHTML(str)
    str.gsub!(/\[\[.+?\]\]/m) do |tag|
      tag = tag[2..-3]
      if tag =~ /^(.+?)\|(.+)$/
        tag = $1
        name = $2
        '<a href="/wiki/show?title=' + CGI.escape(CGI.unescapeHTML(tag.tr(" ", "_"))) + '">' + name + '</a>'
      else
        '<a href="/wiki/show?title=' + CGI.escape(CGI.unescapeHTML(tag.tr(" ", "_"))) + '">' + tag + '</a>'
      end
    end
    str.gsub!(/\{\{.+?\}\}/m) do |tag|
      tag = tag[2..-3]
      '<a href="/post/index?tags=' + CGI.escape(CGI.unescapeHTML(tag)) + '">' + tag + '</a>'
    end
    str.gsub!(/[Pp]ost #(\d+)/, '<a href="/post/show/\1">post #\1</a>')
    str.gsub!(/[Ff]orum #(\d+)/, '<a href="/forum/show/\1">forum #\1</a>')
    str.gsub!(/[Cc]omment #(\d+)/, '<a href="/comment/show/\1">comment #\1</a>')
    str.gsub!(/[Pp]ool #(\d+)/, '<a href="/pool/show/\1">pool #\1</a>')
    str.gsub!(/\n/m, "<br>")
    str.gsub!(/\[b\](.+?)\[\/b\]/, '<strong>\1</strong>')
    str.gsub!(/\[i\](.+?)\[\/i\]/, '<em>\1</em>')
    str.gsub!(/\[spoilers?\](.+?)\[\/spoilers?\]/m, '<a href="#" class="spoiler" onclick="Comment.spoiler(this); return false;"><span class="spoilerwarning">spoiler</span></a><span class="spoilertext" style="display: none">\1</span>')
    str.gsub!(/\[spoilers?(=(.+))\](.+?)\[\/spoilers?\]/m, '<a href="#" class="spoiler" onclick="Comment.spoiler(this); return false;"><span class="spoilerwarning">\2</span></a><span class="spoilertext" style="display: none">\3</span>')

    # Ruby regexes are in the localization dark ages, so we need to match UTF-8 characters
    # manually:
    utf8_char = '[\xC0-\xFF][\x80-\xBF]+'

    url = "(h?ttps?:\\/\\/(?:[a-zA-Z0-9_\\-#~%.,:;\\(\\)\\[\\]$@!&=+?\\/#]|#{utf8_char})+)"
    str.gsub!(/#{url}|&lt;&lt;#{url}(?:\|(.+?))?&gt;&gt;|&quot;(.+?)&quot;:#{url}/m) do |link| # url or <<url|text>> or "text":url
      if $1 then
        text = $1
	link = text.gsub(/[.;,:'"]+$/, "")
      elsif $2
        link = $2
	if $3 then
	  text = $3
	else
	  text = $2
	end
      else
        text = $4
        link = $5
      end

      if link =~ /^ttp/ then link = "h" + link end
      '<a href="' + link + '">' + text + '</a>'
    end
    str
  end

  def parse_list(str)
    html = ""
    layout = []
    nest = 0

    str.split(/\n/).each do |line|
      if line =~ /^\s*(\*+) (.+)/
        nest = $1.size
        content = parse_inline($2)
      else
        content = parse_inline(line)
      end

      if nest > layout.size
        html += "<ul>"
        layout << "ul"
      end

      while nest < layout.size
        elist = layout.pop
        if elist
          html += "</#{elist}>"
        end
      end

      html += "<li>#{content}</li>"
    end

    while layout.any?
      elist = layout.pop
      html += "</#{elist}>"
    end

    html
  end

  def parse(str)
    # Make sure quote tags are surrounded by newlines
    str.gsub!(/\s*\[quote\]\s*/m, "\n\n[quote]\n\n")
    str.gsub!(/\s*\[\/quote\]\s*/m, "\n\n[/quote]\n\n")
    str.gsub!(/(?:\r?\n){3,}/, "\n\n")
    str.strip!
    blocks = str.split(/(?:\r?\n){2}/)
    
    html = blocks.map do |block|
      case block
      when /^(h[1-6])\.\s*(.+)$/
        tag = $1
        content = $2
        "<#{tag}>" + parse_inline(content) + "</#{tag}>"

      when /^\s*\*+ /
        parse_list(block)
        
      when "[quote]"
        '<blockquote>'
        
      when "[/quote]"
        '</blockquote>'

      else
        '<p>' + parse_inline(block) + "</p>"
      end
    end

    html.join("")
  end
  
  module_function :parse_inline
  module_function :parse_list
  module_function :parse
end

