# frozen_string_literal: true

class TagImplication < ApplicationRecord
  # FIXME: subquery in order
  scope :order_for_listing, lambda {
    order(Arel.sql('is_pending DESC, (SELECT name FROM tags WHERE id = tag_implications.predicate_id), (SELECT name FROM tags WHERE id = tag_implications.consequent_id)'))
  }

  scope :search_by_tag_name, lambda { |query|
    return if query.blank?

    tag_ids = Tag.where('name ILIKE ?', "*#{query}*".to_escaped_for_sql_like).select(:id)

    where('predicate_id IN (?) OR consequent_id IN (?)', tag_ids, tag_ids)
      .order(is_pending: :desc, consequent_id: :asc)
  }

  def self.with_implied(tags)
    return [] if tags.blank?

    all = []
    tags = tags.split if tags.respond_to?(:split) && !tags.is_a?(Array)
    tags = [tags] unless tags.respond_to? :each

    tags.each do |tag|
      all << tag
      results = [tag]

      all = iterate_implied_tag_names(results, all)
    end
    all
  end

  def self.iterate_implied_tag_names(results, all)
    10.times do
      results = find_implied_tag_names(results)

      break unless results.any?

      all += results
    end
    all
  end

  def self.find_implied_tag_names(results)
    connection.select_values(sanitize_sql_array([<<-SQL, results]))
        SELECT t1.name
        FROM tags t1, tags t2, tag_implications ti
        WHERE ti.predicate_id = t2.id
        AND ti.consequent_id = t1.id
        AND t2.name IN (?)
        AND ti.is_pending = FALSE
    SQL
  end

  before_create :validate_uniqueness

  def validate_uniqueness
    return unless self.class.exists? ['(predicate_id = ? AND consequent_id = ?) OR (predicate_id = ? AND consequent_id = ?)', predicate_id, consequent_id, consequent_id, predicate_id]

    errors.add(:base, 'Tag implication already exists')
    throw :abort
  end

  # Destroys the alias and sends a message to the alias's creator.
  def destroy_and_notify(current_user, reason)
    if creator_id && creator_id != current_user.id
      msg = "A tag implication you submitted (#{predicate.name} → #{consequent.name}) was deleted for the following reason: #{reason}."

      Dmail.create(from_id: current_user.id, to_id: creator_id, title: 'One of your tag implications was deleted', body: msg)
    end

    destroy
  end

  def predicate
    Tag.find(predicate_id)
  end

  def consequent
    Tag.find(consequent_id)
  end

  def predicate=(name)
    t = Tag.find_or_create_by_name(name)
    self.predicate_id = t.id
  end

  def consequent=(name)
    t = Tag.find_or_create_by_name(name)
    self.consequent_id = t.id
  end

  def approve(user_id, ip_addr)
    update_columns is_pending: false

    t = Tag.find(predicate_id)
    implied_tags = self.class.with_implied(t.name).join(' ')
    t._posts.available.find_each do |post|
      post.reload
      post.update(tags: "#{post.cached_tags} #{implied_tags}", updater_user_id: user_id, updater_ip_addr: ip_addr)
    end
  end

  def to_xml(options = {})
    { id: id, consequent_id: consequent_id, predicate_id: predicate_id, pending: is_pending }.to_xml(options.reverse_merge(root: 'tag_implication'))
  end

  def as_json(*args)
    { id: id, consequent_id: consequent_id, predicate_id: predicate_id, pending: is_pending }.as_json(*args)
  end
end
