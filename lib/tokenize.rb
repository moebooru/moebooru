require "strscan"

# Split a word into tokens on whitespace, keeping words in quotes together.
# Quotes are removed.  A missing close quote is not treated as an error.
#
# tokenize_with_quotes('hello world')
# ["hello", "world"]
#
# tokenize_with_quotes('"hello world"')
# ["hello world"]
#
# tokenize_with_quotes('"hello world')
# ["hello world"]
#
# tokenize_with_quotes('goodbye "cruel world"')
# ["goodbye", "cruel world"]
#
# tokenize_with_quotes('intitle:"cruel world"')
# ["intitle:cruel world"]
#
# tokenize_with_quotes('a"b c"d')
# ["ab cd"]
module Tokenize
  def parse_token(scanner)
    match = ""
    while true
      if scanner.scan(/[^\s"]+/)
        match += scanner.matched
      elsif scanner.scan(/"/) then
        scanner.scan(/[^"]+/)
        match += scanner.matched
        scanner.scan(/"/)
      else
        break
      end
    end

    return nil if match.empty?
    return match
  end

  def tokenize_with_quotes(text)
    scanner = StringScanner.new(text)

    output = []
    while true
      scanner.scan(/\s+/)
      keyword = parse_token(scanner)
      break if keyword.nil?

      output << keyword
    end

    return output
  end

  module_function :parse_token
  module_function :tokenize_with_quotes
end
