class ActiveRecord::Base
  class << self
    public :sanitize_sql
  end
  
  %w(execute select_value select_values select_all).each do |method_name|
    define_method("#{method_name}_sql") do |sql, *params|
      ActiveRecord::Base.connection.__send__(method_name, self.class.sanitize_sql([sql, *params]))
    end

    self.class.__send__(:define_method, "#{method_name}_sql") do |sql, *params|
      ActiveRecord::Base.connection.__send__(method_name, ActiveRecord::Base.sanitize_sql([sql, *params]))
    end
  end
end

class NilClass
  def id
    raise NoMethodError
  end
end

class String
  def to_escaped_for_sql_like
    # NOTE: gsub(/\\/, '\\\\') is a NOP, you need gsub(/\\/, '\\\\\\') if you want to turn \ into \\; or you can duplicate the matched text
    return self.gsub(/\\/, '\0\0').gsub(/%/, '\\%').gsub(/_/, '\\_').gsub(/\*/, '%')
  end

  def to_escaped_js
    return self.gsub(/\\/, '\0\0').gsub(/['"]/) {|m| "\\#{m}"}.gsub(/\r\n|\r|\n/, '\\n')
  end
end

class Hash
  def included(m)
    m.alias_method :to_xml_orig, :to_xml
  end
  
  def to_xml(options = {})
    if false == options.delete(:no_children)
      to_xml_orig(options)
    else
      options[:indent] ||= 2
      options[:no_children] ||= true
      options[:root] ||= "hash"
      dasherize = !options.has_key?(:dasherize) || options[:dasherize]
      root = dasherize ? options[:root].dasherize : options[:root]
      options.reverse_merge!({:builder => Builder::XmlMarkup.new(:indent => options[:indent]), :root => root})
      options[:builder].instruct! unless options.delete(:skip_instruct)
      options[:builder].tag!(root, self)
    end
  end
end

