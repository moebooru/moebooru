class String
  # Strip out invalid utf8
  def to_valid_utf8
    if RUBY_VERSION < '1.9'
      # Use iconv on ruby 1.8.x
      require 'iconv'
      ic = Iconv.new('UTF-8//IGNORE', 'UTF-8')
      # The weird iconv parameter is required thanks to iconv not stripping
      # invalid character if it's at the end of input string.
      # Reference:
      # - http://po-ru.com/diary/fixing-invalid-utf-8-in-ruby-revisited
      return ic.iconv(self + ' ')[0..-2]
    else
      # On later ruby version (1.9), translate the string first to
      # another utf plane (in this case, utf-16).
      # The rails input for some reason is not utf-8 but binary
      # while it really is utf-8. Therefore it must first be marked as utf-8.
      return self.force_encoding('UTF-8').encode('UTF-16', :invalid => :replace, :replace => '').encode('UTF-8')
    end
  end

  # Escapes string to be usable in a SQL LIKE.
  # Adds backslash to \, %, and _ and replace * with % (SQL wildcard)
  def to_escaped_for_sql_like
    return self.gsub(/[\\%_]/) { |x| '\\' + x }.gsub('*', '%')
  end

  # The characters \()&|!: must be escaped
  # by prepending them with \ before passed to tsquery.
  def to_escaped_for_tsquery
    return self.gsub(/[\\()&|!:]/) { |x| '\\' + x }
  end

  def to_escaped_js
    return self.gsub(/\\/, '\0\0').gsub(/['"]/) {|m| "\\#{m}"}.gsub(/\r\n|\r|\n/, '\\n')
  end
end
