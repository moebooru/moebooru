# encoding: utf-8

class String
  # Strip out invalid utf8
  if RUBY_VERSION > "2.1"
    def to_valid_utf8
      str = self
      str.force_encoding Encoding::UTF_8
      str.scrub("?").delete("\u0000")
    end
  elsif RUBY_VERSION > "1.9"
    def to_valid_utf8
      str = self
      str.force_encoding Encoding::UTF_8
      unless str.valid_encoding?
        str.encode!(Encoding::UTF_16LE,
                    :invalid => :replace,
                    :undef => :replace,
                    :replace => "?").encode! Encoding::UTF_8
      end
      str
    end
  else
    require "iconv"

    def to_valid_utf8
      # Use iconv on ruby 1.8.x
      ic = Iconv.new("UTF-8//IGNORE", "UTF-8")
      # The weird iconv parameter is required thanks to iconv not stripping
      # invalid character if it"s at the end of input string.
      # Reference:
      # - http://po-ru.com/diary/fixing-invalid-utf-8-in-ruby-revisited
      ic.iconv(self + " ")[0..-2]
    end
  end

  # Returns true if it looks like true
  # Originally, checking == 't' was enough, but somewhere along the way,
  # true is stored as '1' instead.
  # This function allows simple modification without need to update database.
  def trueish?
    %w(1 t).include? self
  end

  # Escapes string to be usable in a SQL LIKE.
  # Adds backslash to \, %, and _ and replace * with % (SQL wildcard)
  def to_escaped_for_sql_like
    gsub(/[\\%_]/) { |x| '\\' + x }.gsub("*", "%")
  end

  # Nuke nulls and anything after it because it sucks.
  # The characters \()&|!:' and any spaces (\p{Space}) must be escaped
  # by prepending them with \ before passed to tsquery.
  def to_escaped_for_tsquery
    gsub(/\0.*/, "").gsub(/[\p{Space}\\()&|!:']/) { |x| '\\' + x }
  end

  def to_escaped_js
    gsub(/\\/, '\0\0').gsub(/['"]/) { |m| "\\#{m}" }.gsub(/\r\n|\r|\n/, '\\n')
  end
end
