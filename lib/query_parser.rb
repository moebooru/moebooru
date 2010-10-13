module QueryParser
  # Extracts the tokens from a query string
  #
  # === Parameters
  # * :query_string<String>: the query to parse
  def parse(query_string)
    return query_string.to_s.downcase.scan(/\S+/)
  end
  
  # Extracts the metatokens (tokens matching \S+:\S+). Returns a two element array: the first element contains plain tokens, and the second element contains metatokens.
  #
  # === Parameters
  # * :parsed_query<Array>: a list of tokens
  def parse_meta(parsed_query)
    hoge = [[], {}]
    
    parsed_query.each do |token|
      if token =~ /^(.+?):(.+)$/
        hoge[1][$1] = $2
      else
        hoge[0] << token
      end
    end
    
    return hoge
  end

  # Given an array of keywords to search for, return an array of strings for to_tsquery.
  # Words need to be escaped to prevent to_tsquery from parsing them as its own clumsy
  # search syntax; note that this is separate from SQL string escaping, and the final SQL
  # query will ultimately be double-escaped.
  def escape_for_tsquery(array)
    array.map do |token|
      next if token.empty?
      escaped_token = token.gsub(/\\|'/, '\0\0\0\0')
      "'" + escaped_token + "'"
    end.compact
  end
  
  module_function :parse
  module_function :parse_meta
  module_function :escape_for_tsquery
end
