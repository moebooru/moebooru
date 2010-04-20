class HistoryChange < ActiveRecord::Base
  belongs_to :history
  belongs_to :previous, :class_name => "HistoryChange", :foreign_key => :previous_id
  after_create :set_previous

  def options
    master_class.get_versioned_attribute_options(field) or {}
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
    column = master_class.columns_hash[field]
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
                    :field => self.field,
                    :value => get_default
  end

  # Return the object this change modifies.
  def obj
    @obj ||= master_class.find(self.remote_id)
    @obj
  end

  def latest
    HistoryChange.find(:first, :order => "id DESC",
                 :conditions => ["table_name = ? AND remote_id = ? AND field = ?", table_name, remote_id, field])
  end

  def next
    HistoryChange.find(:first, :order => "h.id ASC",
                 :conditions => ["table_name = ? AND remote_id = ? AND id > ? AND field = ?", table_name, remote_id, id, field])
  end

  def set_previous
    self.previous = HistoryChange.find(:first, :order => "id DESC",
                 :conditions => ["table_name = ? AND remote_id = ? AND id < ? AND field = ?", table_name, remote_id, id, field])
    self.save!
  end
end

