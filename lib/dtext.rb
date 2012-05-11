require 'nokogiri'

module DText
  def parse(str)

    state = []

    # Normalize newlines
    str.gsub!(/(\r?\n)/m, "\n")
    str.gsub!(/\n{3,}/m, "\n\n")

    # Keep newline, use carriage return for split
    str.gsub!(/(\n+)/m, '\1' + "\r")
    data = str.split("\r")

    data.each do |d|

    end

  end

  def parseline( )

    str.gsub(/^(h[1-6])\.\s+(.+)\n*/m, '<\1>\2</\1>')
  end

end
