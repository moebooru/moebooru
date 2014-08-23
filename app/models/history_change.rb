class HistoryChange < ActiveRecord::Base
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
      if opts.is_a? Array then
        opts = opts.reduce({}) {|h,pairs| pairs.each {|k,v| h[k] = v}; h}
      end
      return opts
    end
    return master_class.get_versioned_attribute_options(column_name) || {}
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
    return false if not has_default?

    # Cast our value to the actual type; if this is a boolean value, this
    # casts "f" to false.
    column = master_class.columns_hash[column_name]
    typecasted_value = column.type_cast(value)

    return typecasted_value == get_default
  end

  def is_obsolete?
    latest_change = latest
    return self.value != latest_change.value
  end

  def has_default?
    options.has_key?(:default)
  end

  def get_default
    default = options[:default]
  end

  # Return the default value for the field recorded by this change.
  def default_history
    return nil if not has_default?

    History.new :table_name => self.table_name,
                    :remote_id => self.remote_id,
                    :column_name => self.column_name,
                    :value => get_default
  end

  # Return the object this change modifies.
  def obj
    @obj ||= master_class.find(self.remote_id)
    @obj
  end

  def latest
    HistoryChange.find(:first, :order => "id DESC",
                 :conditions => ["table_name = ? AND remote_id = ? AND column_name = ?", table_name, remote_id, column_name])
  end

  def next
    HistoryChange.find(:first, :order => "h.id ASC",
                 :conditions => ["table_name = ? AND remote_id = ? AND id > ? AND column_name = ?", table_name, remote_id, id, column_name])
  end

  def set_previous
    self.previous = HistoryChange.find(:first, :order => "id DESC",
                 :conditions => ["table_name = ? AND remote_id = ? AND id < ? AND column_name = ?", table_name, remote_id, id, column_name])
    self.save!
  end
end

