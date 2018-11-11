class History < ApplicationRecord
  belongs_to :user
  has_many :history_changes, -> { order("id") }

  def aux
    return {} if aux_as_json.nil?
    JSON.parse(aux_as_json)
  end

  def aux=(o)
    if o.empty?
      self.aux_as_json = nil
    else
      self.aux_as_json = o.to_json
    end
  end

  def group_by_table_class
    Object.const_get(group_by_table.classify)
  end

  def get_group_by_controller
    group_by_table_class.get_versioning_group_by[:controller]
  end

  def get_group_by_action
    group_by_table_class.get_versioning_group_by[:action]
  end

  def group_by_obj
    group_by_table_class.find(group_by_id)
  end

  def user
    User.find(user_id)
  end

  def author
    User.find_name(user_id)
  end

  # Undo all changes in the array changes.
  def self.undo(changes, user, redo_change = false, errors = {})
    # Save parent objects after child objects, so changes to the children are
    # committed when we save the parents.
    objects = {}

    changes.each do |change|
      # If we have no previous change, this was the first change to this property
      # and we have no default, so this change can't be undone.
      previous_change = change.previous
      if !previous_change && !change.options[:allow_reverting_to_default]
        next
      end

      unless user.can_change?(change.obj, change.column_name.to_sym)
        errors[change] = :denied
        next
      end

      # Add this node and its parent objects to objects.
      node = cache_object_recurse(objects, change.table_name, change.remote_id, change.obj)
      node[:changes] ||= []
      node[:changes] << change
    end

    return unless objects[:objects]

    # objects contains one or more trees of objects.  Flatten this to an ordered
    # list, so we can always save child nodes before parent nodes.
    done = {}
    stack = []
    objects[:objects].each do |_table_name, rhs|
      rhs.each do |_id, node|
        # Start adding from the node at the top of the tree.
        while node[:parent]
          node = node[:parent]
        end
        stack_object_recurse(node, stack, done)
      end
    end

    stack.reverse_each do |node|
      object = node[:o]
      object.run_callbacks :undo do
        changes = node[:changes]
        if changes
          changes.each do |change|
            if redo_change
              redo_func = ("%s_redo" % change.column_name).to_sym
              if object.respond_to?(redo_func)
                object.send(redo_func, change)
              else
                object.attributes = { change.column_name.to_sym => change.value }
              end
            else
              undo_func = ("%s_undo" % change.column_name).to_sym
              if object.respond_to?(undo_func)
                object.send(undo_func, change)
              else
                if change.previous
                  previous = change.previous.value
                else
                  previous = change.options[:default] # when :allow_reverting_to_default
                end
                object.attributes = { change.column_name.to_sym => previous }
              end
            end
          end
        end
      end

      object.save!
    end
  end

  def self.generate_sql(options = {})
    Nagato::Builder.new do |builder, cond|
      cond.add_unless_blank "histories.remote_id = ?", options[:remote_id]
      cond.add_unless_blank "histories.user_id = ?", options[:user_id]

      if options[:user_name]
        builder.join "users ON users.id = histories.user_id"
        cond.add "users.name = ?", options[:user_name]
      end
    end.to_hash
  end

  private

  # Find and return the node for table_name/id in objects.  If the node doesn't
  # exist, create it and point it at object.
  def self.cache_object(objects, table_name, id, object)
    objects[:objects] ||= {}
    objects[:objects][table_name] ||= {}
    objects[:objects][table_name][id] ||= {
      :o => object
    }
    objects[:objects][table_name][id]
  end

  # Find and return the node for table_name/id in objects.  Recursively create
  # nodes for parent objects.
  def self.cache_object_recurse(objects, table_name, id, object)
    node = cache_object(objects, table_name, id, object)

    # If this class has a master class, register the master object for update callbacks too.
    master = object.versioned_master_object
    if master
      master_node = cache_object_recurse(objects, master.class.to_s, master.id, master)

      master_node[:children] ||= []
      master_node[:children] << node
      node[:parent] = master_node
    end

    node
  end

  # Recursively add all nodes to stack, parents first.
  def self.stack_object_recurse(node, stack, done = {})
    return if done[node]
    done[node] = true

    stack << node

    if node[:children]
      node[:children].each do |child|
        stack_object_recurse(child, stack, done)
      end
    end
  end
end
