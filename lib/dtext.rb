# encoding: utf-8

require 'cgi'
require 'hpricot'

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
    str.gsub!(/\[spoilers?\](.+?)\[\/spoilers?\]/m, '<span href="#" class="spoiler" onclick="Comment.spoiler(this); return false;"><span class="spoilerwarning">spoiler</span></span><span class="spoilertext" style="display: none">\1</span>')
    str.gsub!(/\[spoilers?(=(.+?))\](.+?)\[\/spoilers?\]/m, '<span href="#" class="spoiler" onclick="Comment.spoiler(this); return false;"><span class="spoilerwarning">\2</span></span><span class="spoilertext" style="display: none">\3</span>')

    if RUBY_VERSION < '1.9' then
      # Ruby regexes are in the localization dark ages, so we need to match UTF-8 characters
      # manually:
      utf8_char = '[\xC0-\xFF][\x80-\xBF]+'
  
      url = "(h?ttps?:\\/\\/(?:[a-zA-Z0-9_\\-#~%.,:;\\(\\)\\[\\]$@!&=+?\\/#]|#{utf8_char})+)"
    else
      url = "(h?ttps?://[^ |]+)"
    end
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

  # Split a DText-formatted block (an HTML fragment) into individual quote blocks.  This
  # changes:
  # 
  # <div><blockquote>text</blockquote></div>
  #
  # to
  # <div><block id='1'/></div>
  # and
  # <blockquote>text</blockquote>
  #
  # This allows translating each quotation separately.  These blocks are reconstructed into
  # a single HTML fragment using combine_blocks.
  def split_block(doc, blocks, next_seq=[1])
    while true
      element = doc.at("//blockquote")
      break if element.nil?

      seq = next_seq[0]
      next_seq[0] += 1

      element.swap("<block id='%i'/>" % seq)

      element = split_block(element, blocks, next_seq)
      blocks[seq] = element.to_html
    end

    return doc
  end

  def split_blocks(html, blocks)
    doc = Hpricot(html)
    block = split_block(doc, blocks)
    blocks[0] = block.to_html
  end

  def combine_block(top, blocks, logging_id = nil)
    doc = Hpricot(top)
    doc.search("block").each { |b|
      id = b.get_attribute("id").to_i
      if not blocks.include?(id) then
        logging_id ||= "(unknown)"
        raise "Comment fragment requires fragment ##{id} which doesn't exist: comment ##{logging_id}, #{b}"
      end
      block = blocks[id]
      final_block = combine_block(block, blocks)
      b.swap(final_block)
    }
    return doc.to_html
  end

  def combine_blocks(blocks, logging_id = nil)
    return combine_block(blocks[0], blocks, logging_id)
  end

  # Add the specified class to all top-level HTML elements.
  def add_html_class(html, add)
    doc = Hpricot(html)
    doc.children.each { |c|
      cls = c.get_attribute("class")
      cls ||= ""
      cls += " " if not cls.empty?
      cls += add
      c.set_attribute("class", cls)
    }
    return doc.to_html
  end

  module_function :split_block, :split_blocks, :combine_block, :combine_blocks, :add_html_class
end

