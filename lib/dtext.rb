require 'cgi'
require 'nokogiri'

module DText
  def parse(str)
    state = ['newline']
    result = ""

    # Normalize newlines
    str.strip
    str.gsub!(/(\r?\n)/, "\n")
    str.gsub!(/\n{3,}/, "\n\n")

    # Keep newline, use carriage return for split
    str.gsub!(/(\n+)/, '\1' + "\r")
    data = str.split("\r")

    data.each do |d|
      result << parseline(d, state)
    end

    Nokogiri::HTML::DocumentFragment.parse(result).to_html
  end

  def parseinline(str)
    str = CGI.escapeHTML str
    str.gsub!(/\[\[(.+?)\|(.+?)\]\]/) do
      "<a href=\"/wiki/show?title=#{CGI.escape(CGI.unescapeHTML($1.tr(" ", "_")))}\">#{$2}</a>"
    end
    str.gsub!(/\[\[(.+?)\]\]/) do
      t = $1 if $1
      "<a href=\"/wiki/show?title=#{CGI.escape(CGI.unescapeHTML(t.tr(" ", "_")))}\">#{t}</a>"
    end
    str.gsub!(/\{\{(.+?)\}\}/) do
      t = $1 if $1
      "<a href=\"/post/index?tags=#{CGI.escape(CGI.unescapeHTML(t))}\">#{t}</a>"
    end
    str.gsub! /\[b\](.+)\[\/b\]/, '<strong>\1</strong>'
    str.gsub! /\[i\](.+)\[\/i\]/, '<em>\1</em>'
    str.gsub! /(^|\s+)[Pp]ost #(\d+)(\s+|$)/, '\1<a href="/post/show/\2">post #\2</a>\3'
    str.gsub! /(^|\s+)[Ff]orum #(\d+)(\s+|$)/, '\1<a href="/forum/show/\2">forum #\2</a>\3'
    str.gsub! /(^|\s+)[Cc]omment #(\d+)(\s+|$)/, '\1<a href="/comment/show/\2">comment #\2</a>\3'
    str.gsub! /(^|\s+)[Pp]ool #(\d+)(\s+|$)/, '\1<a href="/pool/show/\2">pool #\2</a>\3'
    str.gsub! /\[spoilers?\]/, '<span href="#" class="spoiler" onclick="Comment.spoiler(this); return false;"><span class="spoilerwarning">spoiler</span></span><span class="spoilertext" style="display: none">'
    str.gsub! /\[spoilers?=(.+?)\]/, '<span href="#" class="spoiler" onclick="Comment.spoiler(this); return false;"><span class="spoilerwarning">\1</span></span><span class="spoilertext" style="display: none">'
    str.gsub! /\[\/spoilers?\]/, '</span>'
    str.gsub! /\[quote\]/, '<blockquote><div>'
    str.gsub! /\[\/quote\]/, '</div></blockquote>'
    str.gsub! /\n/, '<br>'
    str = parseurl(CGI.unescapeHTML(str))
    str
  end

  def parseline(str, state)
    if state.last =~ /\d/ or str =~ /^\*+\s+/
      parselist str, state
    elsif str =~ /^(h[1-6])\.\s*(.+)\n*/
      tag = $1 if $1
      str = "<#{tag}>#{parseinline($2)}</#{tag}>"
    else
      parseinline str
    end
  end

  def parselist(str, state)
    html = ""
    if not state.last =~ /\d/
      state.push "1"
      html << "<ul>"
    else
      n = str.split()[0].count("*")
      if n < state.last.to_i
        html << '</ul>' * (state.last.to_i - n)
        state[-1] = n.to_s
      elsif n > state.last.to_i
        html << '<ul>'
        state[-1] = (state.last.to_i + 1).to_s
      end
    end
    if not str =~ /^\*+\s+/
      state.pop
      html << "</ul>"
      return html + parseline(str, state)
    end
    html << str.gsub(/\*+\s+(.+)\n*/) do 
      "<li>#{parseinline($1)}</li>"
    end
  end

  def parseurl(str)
    url_pattern = /(h?ttps?:\/\/([\w\-_]+)(\.[\w\-_]+)*(:\d+)*(\/[^\s]*)*)/
    str = str.gsub(/(^|\s+)<<\s*(.+?)\s*\|\s*(.+?)\s*>>(\s+|$)/) do |match|
      head = $1 if $1
      link = $2 if $2
      name = $3 if $3
      tail= $4 if $4
      if link =~ url_pattern
        "#{head}<a href=\"#{$1}\">#{name}</a>#{tail}"
      end
    end
    str = str.gsub(/(^|\s+)"(.+?)":#{url_pattern}/, '\1<a href="\3">\2</a>')
    str = str.gsub(/(^|\s+)<<\s*#{url_pattern}\s*>>(?=\s+|$)/, '\1<a href="\2">\2</a>\6')
    str = str.gsub(/(^|\s+)#{url_pattern}/, '\1<a href="\2">\2</a>')
    str
  end

  module_function :parse, :parseline, :parseinline, :parselist, :parseurl
end
