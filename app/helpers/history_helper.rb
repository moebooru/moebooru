# encoding: utf-8
require 'post_helper'
require 'diff'

module HistoryHelper
  include PostHelper
  # :all: By default, some changes are not displayed.  When displaying details
  # for a single change, set :all=>true to display all changes.
  #
  # :show_all_tags: Show unchanged tags.
  def get_default_field_options
    @default_field_options ||= {
      :suppress_fields => [],
    }
  end

  def get_attribute_options
    return @att_options if @att_options

    @att_options = {
      # :suppress_fields => If this attribute was changed, don't display changes to specified
      # fields to the same object in the same change.
      #
      # :force_show_initial => For initial changes, created when the object itself is created,
      # attributes that are set to an explicit :default are omitted from the display.  This
      # prevents things like "parent:none" being shown for every new post.  Set :force_show_initial
      # to override this behavior.
      #
      # :primary_order => Changes are sorted alphabetically by field name.  :primary_order
      # overrides this sorting with a top-level sort (default 1).
      #
      # :never_obsolete => Changes that are no longer current or have been reverted are
      # given the class "obsolete".  Changes in fields named by :never_obsolete are not
      # tested.
      #
      # Some cases:
      #
      # - When viewing a single object (eg. "post:123"), the display is always changed to
      # the appropriate type, so if we're viewing a single object, :specific_table will
      # always be true.
      #
      # - Changes to pool descriptions can be large, and are reduced to "description changed"
      # in the "All" view.  The diff is displayed if viewing the Pool view or a specific object.
      #
      # - Adding a post to a pool usually causes the sequence number to change, too, but
      # this isn't very interesting and clutters the display.  :suppress_fields is used
      # to hide these unless viewing the specific change.
      :Post => {
        :fields => {
          :cached_tags => { :primary_order => 2 }, # show tag changes after other things
          :source => { :primary_order => 3 },
        },
        :never_obsolete => {:cached_tags=>true} # tags handle obsolete themselves per-tag
      },

      :Pool => {
        :primary_order => 0,

        :fields => {
          :description => { :primary_order => 5 } # we don't handle commas correctly if this isn't last
        },
        :never_obsolete => {:description=>true} # changes to description aren't obsolete just because the text has changed again
      },

      :PoolPost => {
        :fields => {
          :sequence => { :max_to_display => 5 },
          :active => {
            :max_to_display => 10,
            :suppress_fields => [:sequence], # changing active usually changes sequence; this isn't interesting
            :primary_order => 2, # show pool post changes after other things
          },
          :cached_tags => {  },
        },
      },

      :Tag => {
      },

      :Note => {
      },
    }

    @att_options.each_key { |classname|
      @att_options[classname] = {
        :fields => {},
        :primary_order => 1,
        :never_obsolete => {},
        :force_show_initial => {},
      }.merge(@att_options[classname])

      c = @att_options[classname][:fields]
      c.each_key { |field|
        c[field] = get_default_field_options.merge(c[field])
      }
    }

    return @att_options
  end

  def format_changes(history, options={})
    html = ""

    changes = history.history_changes

    # Group the changes by class and field.
    change_groups = {}
    changes.each do |c|
      change_groups[c.table_name] ||= {}
      change_groups[c.table_name][c.field.to_sym] ||= []
      change_groups[c.table_name][c.field.to_sym] << c
    end

    att_options = get_attribute_options

    # Number of changes hidden (not including suppressions):
    hidden = 0
    parts = []
    change_groups.each do |table_name, fields|
      # Apply supressions.
      to_suppress = []
      fields.each do |field, group|
        class_name = group[0].master_class.to_s.to_sym
        table_options = att_options[class_name] ||= {}
        field_options = table_options[:fields][field] || get_default_field_options
        to_suppress += field_options[:suppress_fields]
      end

      to_suppress.each { |suppress| fields.delete(suppress) }

      fields.each do |field, group|
        class_name = group[0].master_class.to_s.to_sym
        table_options = att_options[class_name] ||= {}
        field_options = table_options[:fields][field] || get_default_field_options

        # Check for entry limits.
        if not options[:specific_history]
          max = field_options[:max_to_display]
          if max && group.length > max
            hidden += group.length - max
            group = group[0,max] || []
          end
        end

        # Format the rest.
        group.each do |c|
          if !c.previous && c.changes_to_default? && !table_options[:force_show_initial][field]
            next
          end

          part = format_change(history, c, options, table_options)
          next if not part

          part = part.merge(:primary_order => field_options[:primary_order] || table_options[:primary_order])
          parts << part
        end
      end
    end

    parts.sort! { |a,b|
      comp = 0
      [:primary_order, :field, :sort_key].each { |field|
        comp = a[field] <=> b[field]
        break if comp != 0
      }
      comp
    }

    parts.each_index { |idx|
      next if idx == 0
      next if parts[idx][:field] == parts[idx-1][:field]
      parts[idx-1][:html] << ", "
    }

    html = ""

    if !options[:show_name] && history.group_by_table == "tags"
      tag = history.history_changes.first.obj
      html << tag_link(tag.name)
      html << ": "
    end

    if history.aux["note_body"]
      body = history.aux["note_body"]
      body = body[0, 20] + "..." if body.length > 20
      html << "note #{h(body)}: "
    end

    html << parts.map { |part| part[:html] }.join(" ")

    if hidden > 0
      html << " (#{link_to("%i more..." % hidden, :search => "change:%i" % history.id)})"
    end

    return html
  end

  def format_change(history, change, options, table_options)
    html = ""

    classes = []
    if !table_options[:never_obsolete][change.field.to_sym] && change.is_obsolete? then
      classes << ["obsolete"]
    end

    added = %{<span class="added">+</span>}
    removed = %{<span class="removed">-</span>}

    sort_key = change.remote_id
    primary_order = 1
    case change.table_name
    when"posts"
      case change.field
      when "rating"
        html << %{<span class="changed-post-rating">rating:}
        html << change.value
        if change.previous then
          html << %{←}
          html << change.previous.value
        end
        html << %{</span>}
      when "parent_id"
        html << "parent:"
        if change.value
          begin
            new = Post.find(change.value.to_i)
            html << link_to("%i" % new.id, :controller => "post", :action => "show", :id => new.id)
          rescue ActiveRecord::RecordNotFound => e
            html << "%i" % change.value.to_i
          end
        else
          html << "none"
        end

        if change.previous
          html << %{←}
          if change.previous.value
            begin
              old = Post.find(change.previous.value.to_i)
              html << link_to("%i" % old.id, :controller => "post", :action => "show", :id => old.id)
            rescue ActiveRecord::RecordNotFound => e
              html << "%i" % change.previous.value.to_i
            end
          else
            html << "none"
          end
        end

      when "source"
        if change.previous
          html << "source changed from <span class='name-change'>%s</span> to <span class='name-change'>%s</span>" % [source_link(change.previous.value, false), source_link(change.value, false)]
        else
          html << "source: <span class='name-change'>%s</span>" % [source_link(change.value, false)]
        end

      when "frames_pending"
        html << "frames changed: #{h(change.value.empty? ? '(none)':change.value)}"

      when "is_rating_locked"
        html << (change.value == 't' ? added : removed)
        html << "rating-locked"

      when "is_note_locked"
        html << (change.value == 't' ? added : removed)
        html << "note-locked"

      when "is_shown_in_index"
        html << (change.value == 't' ? added : removed)
        html << "shown"

      when "cached_tags"
        previous = change.previous

        changes = Post.tag_changes(change, previous, change.latest)

        list = []
        list += tag_list(changes[:added_tags], :obsolete => changes[:obsolete_added_tags], :prefix => "+", :class => "added")
        list += tag_list(changes[:removed_tags], :obsolete => changes[:obsolete_removed_tags], :prefix=>"-", :class => "removed")

        if options[:show_all_tags]
          list += tag_list(changes[:unchanged_tags], :prefix => "", :class => "unchanged")
        end
        html << list.join(" ")
      end
    when "pools"
      primary_order = 0

      case change.field
      when "name"
        if change.previous
          html << "name changed from <span class='name-change'>%s</span> to <span class='name-change'>%s</span>" % [h(change.previous.value), h(change.value)]
        else
          html << "name: <span class='name-change'>%s</span>" % [h(change.value)]
        end

      when "description"
        if change.value == "" then
          html << "description removed"
        else
          if not change.previous then
            html << "description: "
          elsif change.previous.value == "" then
            html << "description added: "
          else
            html << "description changed: "
          end

          # Show a diff if there's a previous description and it's not blank.  Otherwise,
          # just show the new text.
          show_diff = change.previous && change.previous.value != ""
          if show_diff
            text = Danbooru.diff(change.previous.value, change.value)
          else
            text = h(change.value)
          end

          # If there's only one line in the output, just show it inline.  Otherwise, show it
          # as a separate block.
          multiple_lines = text.include?("<br>")

          show_in_detail = options[:specific_history] || options[:specific_object]
          if not multiple_lines then
            display = text
          elsif show_diff then
            display = "<div class='diff text-block'>#{text}</div>"
          else
            display = "<div class='initial-diff text-block'>#{text}</div>"
          end

          if multiple_lines and not show_in_detail then
            html << "<a onclick='$(this).hide(); $(this).next().show()' href='#'>(show changes)</a><div style='display: none;'>#{display}</div>"
          else
            html << display
          end
        end
      when "is_public"
        html << (change.value == 't' ? added : removed)
        html << "public"
      when "is_active"
        html << (change.value == 't' ? added : removed)
        html << "active"
      end
    when "pools_posts"
      # Sort the output by the post id.
      sort_key = change.obj.post.id
      case change.field
      when "active"
        html << (change.value == 't' ? added : removed)

        html << link_to("post&nbsp;#%i" % change.obj.post_id, :controller => "post", :action => "show", :id => change.obj.post_id)

      when "sequence"
        seq = "order:%i:%s" % [change.obj.post_id, change.value]
        if change.previous then
          seq << %{←#{change.previous.value}}
        end
        html << link_to("%s" % seq, :controller => "post", :action => "show", :id => change.obj.post_id)
      end
    when "tags"
      case change.field
      when "tag_type"
        html << "type:"
        tag_type = Tag.type_name_from_value(change.value.to_i)
        html << %{<span class="tag-type-#{tag_type}">#{tag_type}</span>}
        if change.previous then
          tag_type = Tag.type_name_from_value(change.previous.value.to_i)
          html << %{←<span class="tag-type-#{tag_type}">#{tag_type}</span>}
        end
      when "is_ambiguous"
        html << (change.value == 't' ? added : removed)
        html << "ambiguous"
      end
    when "notes"
      case change.field
      when "body"
        if change.previous
          html << "body changed from <span class='name-change'>%s</span> to <span class='name-change'>%s</span>" % [h(change.previous.value), h(change.value)]
        else
          html << "body: <span class='name-change'>%s</span>" % [h(change.value)]
        end
      when "x"
        html << "x:#{h(change.value)}"
      when "y"
        html << "y:#{h(change.value)}"
      when "height"
        html << "height:#{h(change.value)}"
      when "width"
        html << "width:#{h(change.value)}"
      when "is_active"
        if change.value == 't' then
          # Don't show the note initially being set to active.
          return nil if not change.previous
          html << "undeleted"
        else
          html << "deleted"
        end
      end
    end

    span = ""
    span << %{<span class="#{classes.join(" ")}">#{html}</span>}

    return {
      :html => span,
      :field => change.field,
      :sort_key => sort_key,
    }
  end

  def tag_link(name, options = {})
    name ||= "UNKNOWN"
    prefix = options[:prefix] || ""
    obsolete = options[:obsolete] || []

    tag_type = Tag.type_name(name)

    obsolete_tag = ([name] & obsolete).empty? ?  "":" obsolete"
    tag = ""
    tag << %{<span class="tag-type-#{tag_type}#{obsolete_tag}">}
    tag << %{#{prefix}<a href="/post/index?tags=#{u(name)}">#{h(name)}</a>}
    tag << '</span>'
    tag
  end

  def tag_list(tags, options = {})
    return [] if tags.blank?

    html = ""
    html << %{<span class="#{ options[:class] }">}

    tags_html = []
    tags.each do |name|
      tags_html << tag_link(name, options)
    end

    return [] if tags_html.empty?

    html << tags_html.join(" ")
    html << %{</span>}
    return [html]
  end
end
