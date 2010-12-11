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
  alias_method :to_xml_orig, :to_xml
  
  def to_xml(options = {})
    options[:indent] ||= 2
    options[:root] ||= "hash"
    dasherize = !options.has_key?(:dasherize) || options[:dasherize]
    root = options.delete(:root).to_s
    root = root.dasherize if dasherize

    # Treat simple values as attributes, and complex values as children.
    # { :a=>1, :b=>[1] }
    attrs = {}
    children = []
    self.each do |key, value|
      if value.respond_to?(:to_xml) or value.is_a?(Array) then
        # If an array child is empty, omit the node entirely.
        next if value.is_a?(Array) and value.empty?
        children << [key, value]
      else
        attrs[key] = value
      end
    end

    options.reverse_merge!({:builder => Builder::XmlMarkup.new(:indent => options[:indent])})
    if not options[:skip_instruct]
      options[:skip_instruct] = true
      options[:builder].instruct!
    end

    if children.empty? then
      options[:builder].tag!(root, attrs)
    else
      options[:builder].tag!(root, attrs) {
        children.each do |key, child|
          child.to_xml(options.merge(:root => key.to_s))
        end
      }
    end
  end
end

class Array
  alias_method :to_xml_orig, :to_xml

  def to_xml(options = {})
    options[:builder] ||= Builder::XmlMarkup.new

    if not options[:skip_instruct]
      options[:skip_instruct] = true
      options[:builder].instruct!
    end

    root = options.delete(:root) || "array"
    options[:builder].tag!(root) do
      self.each do |value|
        value.to_xml(options)
      end
    end
  end
end

