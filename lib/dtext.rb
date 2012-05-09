require 'nokogiri'

module DText
  def parse(str)
    # split str into lines (separated by single new line)
    # prepare state stack
    # start from empty state

    state = []

    # Normalize newlines
    str.gsub(/(\r?\n){3,}/m, "\n\n")

    data = str.split("\n")

    data.each do |d|

    end

  end

  def parseline( )

    str.gsub(/^(h[1-6])\.\s+(.+)\n*/m, '<\1>\2</\1>')
  end

end
