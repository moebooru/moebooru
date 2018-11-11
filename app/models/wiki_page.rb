require "diff"

class WikiPage < ApplicationRecord
  acts_as_versioned_rails3 :table_name => "wiki_page_versions", :foreign_key => "wiki_page_id", :order => "updated_at DESC"
  before_save :normalize_title
  belongs_to :user
  validates_uniqueness_of :title, :case_sensitive => false
  validates_presence_of :body, :title
  before_validation :ensure_changed, :on => :update

  class << self
    def generate_sql(options)
      joins = []
      conds = []
      params = []

      if options[:title]
        conds << "wiki_pages.title = ?"
        params << options[:title]
      end

      if options[:user_id]
        conds << "wiki_pages.user_id = ?"
        params << options[:user_id]
      end

      joins = joins.join(" ")
      conds = [conds.join(" AND "), *params]

      [joins, conds]
    end
  end

  def normalize_title
    self.title = title.tr(" ", "_").downcase
  end

  def last_version?
    version == next_version.to_i - 1
  end

  def first_version?
    version == 1
  end

  def author
    User.find_name(user_id)
  end

  def pretty_title
    title.tr("_", " ")
  end

  def diff(version)
    otherpage = WikiPage.find_page(title, version)
    Danbooru.diff(body, otherpage.body)
  end

  def self.find_page(title, version = nil)
    return nil if title.blank?

    page = find_by_title(title)
    page.revert_to(version) if version && page

    page
  end

  def self.find_by_title(title)
    find_by "LOWER(title) = LOWER(?)", title.tr(" ", "_")
  end

  # FIXME: history shouldn't be changed on lock/unlock.
  #        We should instead check last post status when editing
  #        instead of doing mass update.
  def lock!
    self.is_locked = true

    transaction do
      execute_sql("UPDATE wiki_pages SET is_locked = TRUE WHERE id = ?", id)
      execute_sql("UPDATE wiki_page_versions SET is_locked = TRUE WHERE wiki_page_id = ?", id)
    end
  end

  def unlock!
    self.is_locked = false

    transaction do
      execute_sql("UPDATE wiki_pages SET is_locked = FALSE WHERE id = ?", id)
      execute_sql("UPDATE wiki_page_versions SET is_locked = FALSE WHERE wiki_page_id = ?", id)
    end
  end

  def rename!(new_title)
    transaction do
      execute_sql("UPDATE wiki_pages SET title = ? WHERE id = ?", new_title, id)
      execute_sql("UPDATE wiki_page_versions SET title = ? WHERE wiki_page_id = ?", new_title, id)
    end
  end

  def to_xml(options = {})
    { :id => id, :created_at => created_at, :updated_at => updated_at, :title => title, :body => body, :updater_id => user_id, :locked => is_locked, :version => version }.to_xml(options.reverse_merge(:root => "wiki_page"))
  end

  def as_json(*args)
    { :id => id, :created_at => created_at, :updated_at => updated_at, :title => title, :body => body, :updater_id => user_id, :locked => is_locked, :version => version }.as_json(*args)
  end

  protected

  def ensure_changed
    unless (changed & %w(title body)).any?
      errors.add :base, :no_change
    end
  end
end
