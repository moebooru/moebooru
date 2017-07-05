require "history_change"
require "history"
require "set"

module Versioned
  def get_versioned_classes
    [Pool, PoolPost, Post, Tag, Note]
  end
  module_function :get_versioned_classes

  def get_versioned_classes_by_name
    val = {}
    get_versioned_classes.each do |cls|
      val[cls.table_name] = cls
    end
    val
  end
  module_function :get_versioned_classes_by_name
end

module ActiveRecord
  module Versioning
    def self.included(base)
      base.extend ClassMethods
      base.define_callbacks :undo
    end

    def remember_new
      @object_is_new = true
    end

    def get_group_by_id
      self[self.class.get_group_by_foreign_key]
    end

    # Get the current History object.  This is reused as long as we're operating on
    # the same group_by_obj (that is, they'll be displayed together in the history view).
    # Only call this when you're actually going to create HistoryChanges, or this will
    # leave behind empty Histories.

    private

    def get_current_history
      # p "get_current_history %s #%i" % [self.class.table_name, id]
      history = Thread.current[:versioning_history]
      if history
        # p "reuse? %s != %s, %i != %i" % [history.group_by_table, self.class.get_group_by_table_name, history.group_by_id, self.get_group_by_id]
        if history.group_by_table != self.class.get_group_by_table_name ||
            history.group_by_id != get_group_by_id
          # p "don't reuse"
          Thread.current[:versioning_history] = nil
          history = nil
        end
      end

      unless history
        options = {
          :group_by_table => self.class.get_group_by_table_name,
          :group_by_id => get_group_by_id,
          :user_id => Thread.current["danbooru-user_id"]
        }

        cb = self.class.versioning_aux_callback
        if cb
          options[:aux] = send(cb)
        end
        history = History.new(options)
        history.save!

        Thread.current[:versioning_history] = history
      end

      history
    end

    public

    def save_versioned_attributes
      transaction do
        self.class.get_versioned_attributes.each do |att, _options|
          # Always save all properties on creation.
          #
          # Don't use _changed?; it'll be true if a field was changed and then changed back,
          # in which case we must not create a change entry.
          old = __send__("%s_before_last_save" % att.to_s)
          new = __send__(att.to_s)

          #          p "%s:  %s -> %s" % [att.to_s, old, new]
          next if old == new && !@object_is_new

          history = get_current_history
          h = HistoryChange.new(:table_name => self.class.table_name,
                                :remote_id => id,
                                :column_name => att.to_s,
                                :value => new,
                                :history_id => history.id)
          h.save!
        end
      end

      # The object has been saved, so don't treat it as new if it's saved again.
      @object_is_new = false

      true
    end

    def versioned_master_object
      parent = self.class.get_versioned_parent
      return nil unless parent
      type = Object.const_get(parent[:class].to_s.classify)
      foreign_key = parent[:foreign_key]
      id = self[foreign_key]
      type.find(id)
    end

    module ClassMethods
      # :default => If a default value is specified, initial changes (created with the
      # object) that set the value to the default will not be displayed in the UI.
      # This is also used by :allow_reverting_to_default.  This value can be set
      # to nil, which will match NULL.  Be sure at least one property has no default,
      # or initial changes will show up as a blank line in the UI.
      #
      # :allow_reverting_to_default => By default, initial changes.  Fields with
      # :allow_reverting_to_default => true can be undone; the default value will
      # be treated as the previous value.
      def versioned(att, *options)
        unless @versioned_attributes
          @versioned_attributes = {}
          after_save :save_versioned_attributes
          after_create :remember_new

          versioning_group_by unless @versioning_group_by
        end

        @versioned_attributes[att] = *options || {}
      end

      # Configure the history display.
      #
      # :class => Group displayed changes with another class.
      # :foreign_key => Key within :class to display.
      # :controller, :action => Route for displaying the grouped class.
      #
      #   versioning_group_by :class => :pool
      #   versioning_group_by :class => :pool, :foreign_key => :pool_id, :action => "show"
      #   versioning_group_by :class => :pool, :foreign_key => :pool_id, :controller => Post
      def versioning_group_by(options = {})
        opt = {
          :class => to_s,
          :controller => to_s,
          :action => "show"
        }.merge(options)

        unless opt[:foreign_key]
          if opt[:class] == to_s
            opt[:foreign_key] = :id
          else
            reflection = reflections[opt[:class]]
            opt[:foreign_key] = reflection.klass.base_class.to_s.foreign_key.to_sym
          end
        end

        @versioning_group_by = opt
      end

      # Configure a callback to fill in auxilliary history information.
      #
      # The callback must return a hash; its contents will be serialized into aux.  This
      # is used where we need additional data for a particular type of history.
      attr_accessor :versioning_aux_callback

      def get_versioned_default(name)
        attr = get_versioned_attributes[name]
        return nil, false if attr.nil?
        return nil, false unless attr.include?(:default)
        [attr[:default], true]
      end

      def get_versioning_group_by
        @versioning_group_by
      end

      def get_group_by_class
        cl = @versioning_group_by[:class].to_s.classify
        Object.const_get(cl)
      end

      def get_group_by_table_name
        get_group_by_class.table_name
      end

      def get_group_by_foreign_key
        @versioning_group_by[:foreign_key]
      end

      # Specify a parent table.  After a change is undone in this table, the
      # parent class will also receive an after_undo message.  If multiple
      # changes are undone together, changes to parent tables will always
      # be undone after changes to child tables.
      def versioned_parent(c, options = {})
        foreign_key = options[:foreign_key]
        foreign_key ||= reflections[c].klass.base_class.to_s.foreign_key
        foreign_key = foreign_key.to_sym
        @versioned_parent = {
          :class => c,
          :foreign_key => foreign_key
        }
      end

      def get_versioned_parent
        @versioned_parent
      end

      def get_versioned_attributes
        @versioned_attributes || {}
      end

      def get_versioned_attribute_options(field)
        get_versioned_attributes[field.to_sym]
      end

      # Called at the start of each request to reset the history object, so we don't reuse an
      # object between requests on the same thread.
      def init_history
        Thread.current[:versioning_history] = nil
      end

      # Add default histories for any new versioned properties.  Group the new fields
      # with existing histories for the same object, if any, so new properties don't
      # fill up the history as if they were new properties.
      #
      # options:
      #
      # :attrs => [:column_name, :column_name2]
      # If set, specifies the attributes to import.  Otherwise, all versioned attributes
      # with no records are imported.
      #
      # :allow_missing => true
      # If set, don't throw an error if we're trying to import a property that doesn't exist
      # in the database.  This is used for initial import, where the versioned properties
      # in the codebase correspond to columns that will be added and imported in a later
      # migration.  This is not used for explicit imports done later, because we want to catch
      # errors (versioned properties that don't match up with column names).
      def update_versioned_tables(c, options = {})
        table_name = c.table_name
        p "Updating %s ..." % [table_name]

        # Our schema doesn't allow us to apply single ON DELETE constraints, so use
        # a rule to do it.  This is Postgresql-specific.
        connection.execute <<-EOS
          CREATE OR REPLACE RULE delete_histories AS ON DELETE TO #{table_name}
          DO (
            DELETE FROM history_changes WHERE remote_id = OLD.id AND table_name = '#{table_name}';
            DELETE FROM histories WHERE group_by_id = OLD.id AND group_by_table = '#{table_name}';
          );
        EOS

        attributes_to_update = []

        if options[:attrs]
          attrs = options[:attrs]

          # Verify that the attributes we were told to update are actually versioned.
          missing_attributes = attrs - c.get_versioned_attributes.keys
          p c.get_versioned_attributes
          unless missing_attributes.empty?
            raise "Tried to add versioned propertes for table \"%s\" that aren't versioned: %s" % [table_name, missing_attributes.join(" ")]
          end
        else
          attrs = c.get_versioned_attributes
        end

        attrs.each do |att, _opts|
          # If any histories already exist for this attribute, assume that it's already been updated.
          next if HistoryChange.find(:first, :conditions => ["table_name = ? AND column_name = ?", table_name, att.to_s])
          attributes_to_update << att
        end
        return if attributes_to_update.empty?

        attributes_to_update = attributes_to_update.select do |att|
          column_exists = select_value_sql "SELECT 1 FROM information_schema.columns WHERE table_name = ? AND column_name = ?", table_name, att.to_s
          if column_exists
            true
          else
            unless options[:allow_missing]
              raise "Expected to add versioned property \"%s\" for table \"%s\", but that column doesn't exist in the database" % [att, table_name]
            end

            false
          end
        end
        return if attributes_to_update.empty?

        transaction do
          current = 1
          count = c.count(:all)
          c.find(:all, :order => :id).each do |item|
            p "%i/%i" % [current, count]
            current += 1

            group_by_table = item.class.get_group_by_table_name
            group_by_id = item.get_group_by_id
            # p "group %s by %s" % [item.to_s, item.class.get_group_by_table_name.to_s]
            history = History.find(:first, :order => "id ASC",
                                           :conditions => ["group_by_table = ? AND group_by_id = ?", group_by_table, group_by_id])

            unless history
              # p "new history"
              options = {
                :group_by_table => group_by_table,
                :group_by_id => group_by_id
              }
              options[:user_id] = item.user_id if item.respond_to?("user_id")
              options[:user_id] ||= 1
              history = History.new(options)
              history.save!
            end

            to_create = []
            attributes_to_update.each do |att|
              value = item.__send__(att.to_s)
              options = {
                :column_name => att.to_s,
                :value => value,
                :table_name => table_name,
                :remote_id => item.id,
                :history_id => history.id
              }

              escaped_options = {}
              options.each do |key, value|
                if value.nil?
                  escaped_options[key] = "NULL"
                else
                  column = HistoryChange.columns_hash[key]
                  quoted_value = Base.connection.quote(value, column)
                  escaped_options[key] = quoted_value
                end
              end

              to_create += [escaped_options]
            end

            columns = to_create.first.map { |key, _value| key.to_s }

            values = []
            to_create.each do |row|
              outrow = []
              columns.each do |col|
                val = row[col.to_sym]
                outrow += [val]
              end
              values += ["(#{outrow.join(",")})"]
            end
            sql = <<-EOS
              INSERT INTO history_changes (#{columns.join(", ")}) VALUES #{values.join(",")}
            EOS
            Base.connection.execute sql
          end
        end
      end

      def import_post_tag_history
        count = PostTagHistory.count(:all)
        current = 1
        PostTagHistory.find(:all, :order => "id ASC").each do |tag_history|
          p "%i/%i" % [current, count]
          current += 1

          prev = tag_history.previous

          tags = tag_history.tags.scan(/\S+/)
          metatags, tags = tags.partition { |x| x =~ /^(?:rating):/ }
          tags = tags.sort.join(" ")

          rating = ""
          prev_rating = ""
          metatags.each do |metatag|
            case metatag
            when /^rating:([qse])/
              rating = Regexp.last_match[1]
            end
          end

          if prev
            prev_tags = prev.tags.scan(/\S+/)
            prev_metatags, prev_tags = prev_tags.partition { |x| x =~ /^(?:-pool|pool|rating|parent):/ }
            prev_tags = prev_tags.sort.join(" ")

            prev_metatags.each do |metatag|
              case metatag
              when /^rating:([qse])/
                prev_rating = Regexp.last_match[1]
              end
            end
          end

          if tags != prev_tags || rating != prev_rating
            h = History.new(:group_by_table => "posts",
                            :group_by_id => tag_history.post_id,
                            :user_id => tag_history.user_id || tag_history.post.user_id,
                            :created_at => tag_history.created_at)
            h.save!
          end
          if tags != prev_tags
            c = h.history_changes.new(:table_name => "posts",
                                      :remote_id => tag_history.post_id,
                                      :column_name => "cached_tags",
                                      :value => tags)
            c.save!
          end

          if rating != prev_rating
            c = h.history_changes.new(:table_name => "posts",
                                      :remote_id => tag_history.post_id,
                                      :column_name => "rating",
                                      :value => rating)
            c.save!
          end
        end
      end

      def import_note_history
        count = NoteVersion.count(:all)
        current = 1
        NoteVersion.find(:all, :order => "id ASC").each do |ver|
          p "%i/%i" % [current, count]
          current += 1

          if ver.version == 1
            prev = nil
          else
            prev = NoteVersion.find(:first, :conditions => ["post_id = ? and note_id = ? and version = ?", ver.post_id, ver.note_id, ver.version - 1])
          end

          fields = []
          [:is_active, :body, :x, :y, :width, :height].each do |field|
            value = ver.send(field)
            if prev
              prev_value = prev.send(field)
              next if value == prev_value
            end
            fields << [field.to_s, value]
          end

          # Only create the History if we actually found any changes.
          if fields.any?
            h = History.new(:group_by_table => "posts",
                            :group_by_id => ver.post_id,
                            :user_id => ver.user_id || ver.post.user_id,
                            :created_at => ver.created_at,
                            :aux => { :note_body => prev ? prev.body : ver.body })
            h.save!

            fields.each do |f|
              c = h.history_changes.new(:table_name => "notes",
                                        :remote_id => ver.note_id,
                                        :column_name => f[0],
                                        :value => f[1])
              c.save!
            end
          end
        end
      end

      # Add base history values for newly-added properties.
      #
      # This is only used for importing initial histories.  When adding new versioned properties,
      # call update_versioned_tables directly with the table and attributes to update.
      def update_all_versioned_tables
        Versioned.get_versioned_classes.each do |cls|
          update_versioned_tables cls, :allow_missing => true
        end
      end
    end
  end
end

ActiveRecord::Base.send :include, ActiveRecord::Versioning
