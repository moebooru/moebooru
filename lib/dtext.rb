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
    parseurl str
    str.gsub! /\[b\](.+)\[\/b\]/, '<strong>\1</strong>'
    str.gsub! /\[i\](.+)\[\/i\]/, '<em>\1</em>'
    str.gsub! /[Pp]ost #(\d+)/, '<a href="/post/show/\1">post #\1</a>'
    str.gsub! /[Ff]orum #(\d+)/, '<a href="/forum/show/\1">forum #\1</a>'
    str.gsub! /[Cc]omment #(\d+)/, '<a href="/comment/show/\1">comment #\1</a>'
    str.gsub! /[Pp]ool #(\d+)/, '<a href="/pool/show/\1">pool #\1</a>'
    str.gsub! /\[spoilers?\]/, '<span href="#" class="spoiler" onclick="Comment.spoiler(this); return false;"><span class="spoilerwarning">spoiler</span></span><span class="spoilertext" style="display: none">'
    str.gsub! /\[spoilers?=(.+)\]/, '<span href="#" class="spoiler" onclick="Comment.spoiler(this); return false;"><span class="spoilerwarning">\1</span></span><span class="spoilertext" style="display: none">'
    str.gsub! /\[\/spoilers?\]/, '</span>'
    str.gsub! /\n/, '<br>'
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
    parseinline str
    html = ""
    if not state.last =~ /\d/
      state.push "1"
      html << "<ul>"
    else
      n = str.split()[0].count("*")
      if n < state.last.to_i
        html << '</ul></li>' * (state.last.to_i - n - 1)
        state[-1] = n.to_s
      elsif n > state.last.to_i
        html << '<li><ul>'
        state[-1] = (state.last.to_i + 1).to_s
      end
    end
    if str =~ /^[^\*]/
      state.pop
      html << "</ul>"
      return html + parseline(str, state)
    end
    html << str.gsub(/\*+\s+(.+)\n*/) do 
      "<li>#{parseinline($1)}</li>"
    end
  end

  def parseurl(str)
    str
  end
end
