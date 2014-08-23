class Tag < ActiveRecord::Base
  include Tag::TypeMethods
  include Tag::CacheMethods
  include Tag::RelatedTagMethods
  include Tag::ParseMethods
  include Tag::ApiMethods
  has_and_belongs_to_many :_posts, :class_name => "Post"
  has_many :tag_aliases, :foreign_key => "alias_id"

  TYPE_ORDER = {}
  CONFIG["tag_order"].each_with_index do |type, index|
    TYPE_ORDER[type] = index
  end

  TAG_TYPE_INDEXES = CONFIG["tag_types"].values.uniq.sort.freeze

  def self.count_by_period(start, stop, options = {})
    options[:limit] ||= 50
    options[:exclude_types] ||= []

    tag_types_to_show = TAG_TYPE_INDEXES - options[:exclude_types]
    Tag.group(:name).joins(:_posts)
      .where(:posts => { :created_at => start..stop }, :tag_type => tag_types_to_show)
      .order("count_all DESC").limit(options[:limit])
      .count
      .map { |name, count| { "post_count" => count, "name" => name } }
  end

  def pretty_name
    name
  end

  def self.find_or_create_by_name(name)
    # Reserve ` as a field separator for tag/summary.
    name = name.downcase.tr(" ", "_").gsub(/^[-~]+/, "").gsub(/`/, "")

    ambiguous = false
    tag_type = nil

    if name =~ /^ambiguous:(.+)/
      ambiguous = true
      name = Regexp.last_match[1]
    end

    if name =~ /^(.+?):(.+)$/  && CONFIG["tag_types"][Regexp.last_match[1]]
      tag_type = CONFIG["tag_types"][Regexp.last_match[1]]
      name = Regexp.last_match[2]
    end

    tag = find_by_name(name)

    if tag
      if tag_type
        tag.update_attributes(:tag_type => tag_type)
      end

      if ambiguous
        tag.update_attributes(:is_ambiguous => ambiguous)
      end

      return tag
    else
      create(:name => name, :tag_type => tag_type || CONFIG["tag_types"]["General"], :cached_related_expires_on => Time.now, :is_ambiguous => ambiguous)
    end
  end

  def self.select_ambiguous(tags)
    return [] if tags.blank?
    select_values_sql("SELECT name FROM tags WHERE name IN (?) AND is_ambiguous = TRUE ORDER BY name", tags)
  end

  def self.purge_tags
    sql =
      "DELETE FROM tags " \
      "WHERE post_count = 0 AND " \
      "id NOT IN (SELECT alias_id FROM tag_aliases UNION SELECT predicate_id FROM tag_implications UNION SELECT consequent_id FROM tag_implications)"
    execute_sql sql
  end

  def self.recalculate_post_count
    sql = "UPDATE tags SET post_count = (SELECT COUNT(*) FROM posts_tags pt, posts p WHERE pt.tag_id = tags.id AND pt.post_id = p.id AND p.status <> 'deleted')"
    execute_sql sql
  end

  def self.mass_edit(start_tags, result_tags, updater_id, updater_ip_addr)
    Post.find_by_tags(start_tags).each do |p|
      start = TagAlias.to_aliased(Tag.scan_tags(start_tags))
      result = TagAlias.to_aliased(Tag.scan_tags(result_tags))
      tags = (p.cached_tags.scan(/\S+/) - start + result).join(" ")
      p.update_attributes(:updater_user_id => updater_id, :updater_ip_addr => updater_ip_addr, :tags => tags)
    end
  end

  def self.find_suggestions(query)
    if query.include?("_") && query.index("_") == query.rindex("_")
      # Contains only one underscore
      search_for = query.split(/_/).reverse.join("_").to_escaped_for_sql_like
    else
      search_for = "%" + query.to_escaped_for_sql_like + "%"
    end

    Tag.where("name LIKE ? AND name <> ?", search_for, query).order("post_count DESC").limit(6).pluck(:name).sort
  end
end
