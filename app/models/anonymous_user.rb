# encoding: utf-8
class AnonymousUser
  def id
    0
  end

  def level
    0
  end

  def name
    CONFIG["default_guest_name"]
  end

  alias_method :pretty_name, :name

  def is_anonymous?
    true
  end

  def has_permission?(_obj, _foreign_key = :user_id)
    false
  end

  def can_change?(record, attribute)
    method = "can_change_#{attribute}?"
    if record.respond_to?(method)
      record.__send__(method, self)
    elsif record.respond_to?(:can_change?)
      record.can_change?(self, attribute)
    else
      false
    end
  end

  def show_samples?
    true
  end

  def has_avatar?
    false
  end

  def language
    ""
  end

  def secondary_languages
    ""
  end

  def secondary_language_array
    []
  end

  def pool_browse_mode
    1
  end

  def always_resize_images
    true
  end

  CONFIG["user_levels"].each do |name, _value|
    normalized_name = name.downcase.gsub(/ /, "_")

    define_method("is_#{normalized_name}?") do
      false
    end

    define_method("is_#{normalized_name}_or_higher?") do
      false
    end

    define_method("is_#{normalized_name}_or_lower?") do
      true
    end
  end

  def blacklisted_tags_array
    CONFIG["default_blacklists"]
  end
end
