class Note < ApplicationRecord
  include ActiveRecord::Acts::Versioned

  belongs_to :post
  before_save :blank_body
  acts_as_versioned_rails3 :table_name => "note_versions", :foreign_key => "note_id", :order => "updated_at DESC"
  after_save :update_post

  versioning_group_by :class => "post"
  versioned :is_active, :default => "f", :allow_reverting_to_default => true
  versioned :x
  versioned :y
  versioned :width
  versioned :height
  versioned :body

  # When any change is made, save the current body to the history record, so we can
  # display it along with the change to identify what was being changed at the time.
  # Otherwise, we'd have to look back through history for each change to figure out
  # what the body was at the time.
  self.versioning_aux_callback = :aux_callback
  def aux_callback
    # If our body has been changed and we have an old one, record it as the body;
    # otherwise if we're a new note and have no old body, record the current one.
    { :note_body => body_before_last_save || body }
  end

  module LockMethods
    def self.included(m)
      m.validate :post_must_not_be_note_locked
    end

    def post_must_not_be_note_locked
      if is_locked?
        errors.add :base, "Post is note locked"
        return false
      end
    end

    def is_locked?
      if select_value_sql("SELECT 1 FROM posts WHERE id = ? AND is_note_locked = ?", post_id, true)
        return true
      else
        return false
      end
    end
  end

  module ApiMethods
    def api_attributes
      {
        :id => id,
        :created_at => created_at,
        :updated_at => updated_at,
        :creator_id => user_id,
        :x => x,
        :y => y,
        :width => width,
        :height => height,
        :is_active => is_active,
        :post_id => post_id,
        :body => body,
        :version => version
      }
    end

    def to_xml(options = {})
      api_attributes.to_xml(options.reverse_merge(:root => "note"))
    end

    def as_json(*args)
      api_attributes.as_json(*args)
    end
  end

  include LockMethods
  include ApiMethods

  def blank_body
    self.body = "(empty)" if body.blank?
  end

  # TODO: move this to a helper
  def formatted_body
    body.gsub(/<tn>(.+?)<\/tn>/m, '<br><p class="tn">\1</p>').gsub(/\n/, "<br>")
  end

  def update_post
    active_notes = select_value_sql("SELECT 1 FROM notes WHERE is_active = ? AND post_id = ? LIMIT 1", true, post_id)

    if active_notes
      execute_sql("UPDATE posts SET last_noted_at = ? WHERE id = ?", updated_at, post_id)
    else
      execute_sql("UPDATE posts SET last_noted_at = ? WHERE id = ?", nil, post_id)
    end
  end

  def author
    User.find_name(user_id)
  end
end
