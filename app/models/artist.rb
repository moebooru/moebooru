class Artist < ApplicationRecord
  module UrlMethods
    module ClassMethods
      def find_all_by_url(url)
        url = ArtistUrl.normalize(url)
        artists = []

        while artists.empty? && url.size > 10
          u = "#{url.to_escaped_for_sql_like}%"
          artists += Artist.joins(:artist_urls).where(:alias_id => nil).where("artist_urls.normalized_url LIKE ?", u).order(:name)

          # Remove duplicates based on name
          artists = artists.each_with_object({}) { |i, a| a[i.name] = i }.values
          url = File.dirname(url)
        end

        artists[0, 20]
      end
    end

    def self.included(m)
      m.extend(ClassMethods)
      m.after_save :commit_urls
      m.has_many :artist_urls, :dependent => :delete_all
    end

    def commit_urls
      if @urls
        artist_urls.clear

        @urls.scan(/\S+/).each do |url|
          artist_urls.create(:url => url)
        end
      end
    end

    attr_writer :urls

    def urls
      artist_urls.map(&:url).join("\n")
    end
  end

  module NoteMethods
    def self.included(m)
      m.after_save :commit_notes
    end

    def wiki_page
      WikiPage.find_page(name)
    end

    def notes_locked?
      wiki_page.is_locked? rescue false
    end

    def notes
      wiki_page.body rescue ""
    end

    attr_writer :notes

    def commit_notes
      unless @notes.blank?
        if wiki_page.nil?
          WikiPage.create(:title => name, :body => @notes, :ip_addr => updater_ip_addr, :user_id => updater_id)
        elsif wiki_page.is_locked?
          errors.add(:notes, "are locked")
        else
          wiki_page.update(:body => @notes, :ip_addr => updater_ip_addr, :user_id => updater_id)
        end
      end
    end
  end

  module AliasMethods
    def self.included(m)
      m.after_save :commit_aliases
    end

    def commit_aliases
      if @alias_names
        transaction do
          self.class.where(:alias_id => id).update_all(:alias_id => nil)
          @alias_names.each do |name|
            a = Artist.find_or_create_by(:name => name)
            a.update(:alias_id => id, :updater_id => updater_id)
          end
        end
      end
    end

    def alias_names=(names)
      @alias_names = names.split(/\s*,\s*/)
    end

    def alias_names
      aliases.map(&:name).join(", ")
    end

    def aliases
      if new_record?
        self.class.none
      else
        self.class.where(:alias_id => id).order(:name)
      end
    end

    def alias_name
      if alias_id
        begin
          return Artist.find(alias_id).name
        rescue ActiveRecord::RecordNotFound
        end
      end

      nil
    end

    def alias_name=(name)
      if name.blank?
        self.alias_id = nil
      else
        artist = Artist.find_or_create_by(:name => name)
        self.alias_id = artist.id
      end
    end
  end

  module GroupMethods
    def self.included(m)
      m.after_save :commit_members
    end

    def commit_members
      transaction do
        self.class.unscoped.where(:group_id => id).update_all(:group_id => nil)

        if @member_names
          @member_names.each do |name|
            a = Artist.find_or_create_by(:name => name)
            a.update(:group_id => id, :updater_id => updater_id)
          end
        end
      end
    end

    def group_name
      return unless group_id

      Artist.find(group_id).name
    end

    def members
      if new_record?
        self.class.none
      else
        self.class.where(:group_id => id).order(:name)
      end
    end

    def member_names
      members.map(&:name).join(", ")
    end

    def member_names=(names)
      @member_names = names.split(/\s*,\s*/)
    end

    def group_name=(name)
      if name.blank?
        self.group_id = nil
      else
        artist = Artist.find_or_create_by(:name => name)
        self.group_id = artist.id
      end
    end
  end

  module ApiMethods
    def api_attributes
      {
        :id => id,
        :name => name,
        :alias_id => alias_id,
        :group_id => group_id,
        :urls => artist_urls.map(&:url)
      }
    end

    def to_xml(options = {})
      attribs = api_attributes
      attribs[:urls] = attribs[:urls].join(" ")
      attribs.to_xml(options.reverse_merge(:root => "artist"))
    end

    def as_json(*args)
      api_attributes.as_json(*args)
    end
  end

  include UrlMethods
  include NoteMethods
  include AliasMethods
  include GroupMethods
  include ApiMethods

  before_validation :normalize
  validates_uniqueness_of :name
  validates_presence_of :name
  belongs_to :updater, :class_name => "User", :foreign_key => "updater_id"
  attr_accessor :updater_ip_addr

  def normalize
    self.name = name.downcase.gsub(/^\s+/, "").gsub(/\s+$/, "").gsub(/ /, "_")
  end

  def to_s
    name
  end
end
