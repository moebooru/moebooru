class HistoryChange < ApplicationRecord
  belongs_to :history
  belongs_to :previous, :class_name => "HistoryChange", :foreign_key => :previous_id
  after_create :set_previous

  def options
    # FIXME: I don't know what I did here.
    # Apparently the return changes between 1.8 and 1.9 -
    # this workaround were found somewhere I couldn't remember.
    # - edogawaconan
    if RUBY_VERSION >= "1.9"
      opts = master_class.get_versioned_attribute_options(column_name) || {}
      if opts.is_a? Array
        opts = opts.each_with_object({}) { |i, a| i.each { |k, v| a[k] = v } }
      end
      return opts
    end
    master_class.get_versioned_attribute_options(column_name) || {}
  end

  def master_class
    # Hack because Rails is stupid and can't reliably derive class names
    # from table names:
    if table_name == "pools_posts"
      class_name = "PoolPost"
    else
      class_name = table_name.classify
    end
    Object.const_get(class_name)
  end

  # Return true if this changes the value to the default value.
  def changes_to_default?
    return false unless has_default?

    # Cast our value to the actual type; if this is a boolean value, this
    # casts "f" to false.
    column = master_class.type_for_attribute(column_name)
    typecasted_value = column.deserialize(value)

    typecasted_value == get_default
  end

  def is_obsolete?
    latest_change = latest
    value != latest_change.value
  end

  def has_default?
    options.key?(:default)
  end

  def get_default
    options[:default]
  end

  # Return the default value for the field recorded by this change.
  def default_history
    return nil unless has_default?

    History.new :table_name => table_name,
                :remote_id => remote_id,
                :column_name => column_name,
                :value => get_default
  end

  # Return the object this change modifies.
  def obj
    @obj ||= master_class.find(remote_id)
  end

  def latest
    self.class.order(:id => :desc).find_by(:table_name => table_name, :remote_id => remote_id, :column_name => column_name)
  end

  def next
    self.class.order(:id => :asc).find_by(:table_name => table_name, :remote_id => remote_id, :column_name => column_name)
  end

  def set_previous
    self.previous = self.class
      .where(:table_name => table_name, :remote_id => remote_id, :column_name => column_name)
      .where("id < ?", id)
      .order(:id => :desc)
      .take
    self.save!
  end
end
