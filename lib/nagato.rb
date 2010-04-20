# Nagato is a library that allows you to programatically build SQL queries.
module Nagato
  # Represents a single subquery.
  class Subquery
    # === Parameters
    # * :join<String>:: Can be either "and" or "or". All the conditions will be joined using this string.
    def initialize(join = "and")
      @join = join.upcase
      @conditions = []
      @condition_params = []
    end

    # Returns true if the subquery is empty.
    def empty?
      return @conditions.empty?
    end

    # Returns an array of 1 or more elements, the first being a SQL fragment and the rest being placeholder parameters.
    def conditions
      if @conditions.empty?
        return ["TRUE"]
      else
        return [@conditions.join(" " + @join + " "), *@condition_params]
      end
    end
    
    # Creates a subquery (within the current subquery).
    #
    # === Parameters
    # * :join<String>:: Can be either "and" or "or". This will be passed on to the generated subquery.
    def subquery(join = "and")
      subconditions = self.class.new(join)
      yield(subconditions)
      c = subconditions.conditions
      @conditions << "(#{c[0]})"
      @condition_params += c[1..-1]
    end
    
    # Adds a condition to the subquery. If the condition has placeholder parameters, you can pass them in directly in :params:.
    #
    # === Parameters
    # * :sql<String>:: A SQL fragment.
    # * :params<Object>:: A list of object to be used as the placeholder parameters.
    def add(sql, *params)
      @conditions << sql
      @condition_params += params
    end
    
    # A special case in which there's only one parameter. If the parameter is nil, then don't add the condition.
    #
    # === Parameters
    # * :sql<String>:: A SQL fragment.
    # * :param<Object>:: A placeholder parameter.
    def add_unless_blank(sql, param)
      unless param == nil || param == ""
        @conditions << sql
        @condition_params << param
      end
    end
  end
  
  class Builder
    attr_reader :order, :limit, :offset
    
    # Constructs a new Builder object. You must use it in block form.
    #
    # Example:
    #
    #   n = Nagato::Builder.new do |builder, cond|
    #     builder.get("posts.id")
    #     builder.get("posts.rating")
    #     builder.rjoin("posts_tags ON posts_tags.post_id = posts.id")
    #     cond.add_unless_blank "posts.rating = ?", params[:rating]
    #     cond.subquery do |c1|
    #       c1.add "posts.user_id is null"
    #       c1.add "posts.user_id = 1"
    #     end
    #   end
    #
    #   Post.find(:all, n.to_hash)
    def initialize
      @select = []
      @joins = []
      @subquery = Subquery.new("and")
      @order = nil
      @offset = nil
      @limit = nil

      yield(self, @subquery)
    end

    # Defines a new join.
    #
    # Example:
    #
    #   cond.join "posts_tags ON posts_tags.post_id = posts.id"
    def join(sql)
      @joins << "JOIN " + sql
    end
    
    # Defines a new left join.
    #
    # Example:
    #
    #   cond.ljoin "posts_tags ON posts_tags.post_id = posts.id"
    def ljoin(sql)
      @joins << "LEFT JOIN " + sql
    end

    # Defines a new right join.
    #
    # Example:
    #
    #   cond.rjoin "posts_tags ON posts_tags.post_id = posts.id"
    def rjoin(sql)
      @joins << "RIGHT JOIN " + sql
    end

    # Defines the select list.
    # 
    # === Parameters
    # * :fields<String, Array>: the fields to select
    def get(fields)
      if fields.is_a?(String)
        @select << fields
      elsif fields.is_a?(Array)
        @select += fields
      else
        raise TypeError
      end
    end

    # Sets the ordering.
    #
    # === Parameters
    # * :sql<String>:: A SQL fragment defining the ordering
    def order(sql)
      @order = sql
    end
    
    # Sets the limit.
    #
    # === Parameters
    # * :amount<Integer>:: The amount
    def limit(amount)
      @limit = amount.to_i
    end
    
    # Sets the offset.
    #
    # === Parameters
    # * :amount<Integer>:: The amount
    def offset(amount)
      @offset = amount.to_i
    end
    
    # Return the conditions (as an array suitable for usage with ActiveRecord)
    def conditions
      return @subquery.conditions
    end

    # Returns the joins (as an array suitable for usage with ActiveRecord)
    def joins
      return @joins.join(" ")
    end
    
    # Converts the SQL fragment as a hash (suitable for usage with ActiveRecord)
    def to_hash
      hash = {}
      hash[:conditions] = conditions
      hash[:joins] = joins unless @joins.empty?
      hash[:order] = @order if @order
      hash[:limit] = @limit if @limit
      hash[:offset] = @offset if @offset
      hash[:select] = @select if @select.any?
      return hash
    end
  end
  
  def find(model, &block)
    return model.find(:all, Builder.new(&block).to_hash)
  end
  
  module_function :find
end

