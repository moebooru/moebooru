class Artist < ActiveRecord::Base
  module UrlMethods
    module ClassMethods
      def find_all_by_url(url)
        url = ArtistUrl.normalize(url)
        artists = []

        while artists.empty? && url.size > 10
          u = url.to_escaped_for_sql_like.gsub(/\*/, '%') + '%'
          artists += Artist.find(:all, :joins => "JOIN artist_urls ON artist_urls.artist_id = artists.id", :conditions => ["artists.alias_id IS NULL AND artist_urls.normalized_url LIKE ? ESCAPE E'\\\\'", u], :order => "artists.name")

          # Remove duplicates based on name
          artists = artists.inject({}) {|all, artist| all[artist.name] = artist ; all}.values
          url = File.dirname(url)
        end

        return artists[0, 20]
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
    
    def urls=(urls)
      @urls = urls
    end

    def urls
      artist_urls.map {|x| x.url}.join("\n")
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

    def notes=(text)
      @notes = text
    end
    
    def commit_notes
      unless @notes.blank?
        if wiki_page.nil?
          WikiPage.create(:title => name, :body => @notes, :ip_addr => updater_ip_addr, :user_id => updater_id)
        elsif wiki_page.is_locked?
          errors.add(:notes, "are locked")
        else
          wiki_page.update_attributes(:body => @notes, :ip_addr => updater_ip_addr, :user_id => updater_id)
        end
      end
    end
  end
  
  module AliasMethods
    def self.included(m)
      m.after_save :commit_aliases
    end
    
    def commit_aliases
      transaction do
        connection.execute("UPDATE artists SET alias_id = NULL WHERE alias_id = #{id}")

        if @alias_names
          @alias_names.each do |name|
            a = Artist.find_or_create_by_name(name)
            a.update_attributes(:alias_id => id, :updater_id => updater_id)
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
        return []
      else
        return Artist.find(:all, :conditions => "alias_id = #{id}", :order => "name")
      end
    end

    def alias_name
      if alias_id
        begin
          return Artist.find(alias_id).name
        rescue ActiveRecord::RecordNotFound
        end
      end

      return nil
    end

    def alias_name=(name)
      if name.blank?
        self.alias_id = nil
      else
        artist = Artist.find_or_create_by_name(name)
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
        connection.execute("UPDATE artists SET group_id = NULL WHERE group_id = #{id}")

        if @member_names
          @member_names.each do |name|
            a = Artist.find_or_create_by_name(name)
            a.update_attributes(:group_id => id, :updater_id => updater_id)
          end
        end
      end
    end
    
    def group_name
      if group_id
        return Artist.find(group_id).name
      else
        nil
      end
    end

    def members
      if new_record?
        return []
      else
        Artist.find(:all, :conditions => "group_id = #{id}", :order => "name")
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
        artist = Artist.find_or_create_by_name(name)
        self.group_id = artist.id
      end
    end
  end
  
  module ApiMethods
    def api_attributes
      return {
        :id => id, 
        :name => name, 
        :alias_id => alias_id, 
        :group_id => group_id,
        :urls => artist_urls.map {|x| x.url}
      }
    end

    def to_xml(options = {})
      attribs = api_attributes
      attribs[:urls] = attribs[:urls].join(" ")
      attribs.to_xml(options.merge(:root => "artist"))
    end

    def to_json(*args)
      return api_attributes.to_json(*args)
    end
  end
  
  include UrlMethods
  include NoteMethods
  include AliasMethods
  include GroupMethods
  include ApiMethods
  
  before_validation :normalize
  validates_uniqueness_of :name
  belongs_to :updater, :class_name => "User", :foreign_key => "updater_id"
  attr_accessor :updater_ip_addr

  def normalize
    self.name = name.downcase.gsub(/^\s+/, "").gsub(/\s+$/, "").gsub(/ /, '_')
  end
  
  def to_s
    return name
  end
  
  def self.generate_sql(name)
    b = Nagato::Builder.new do |builder, cond|
      case name        
      when /^http/
        cond.add "id IN (?)", find_all_by_url(name).map {|x| x.id}
        
      else
        cond.add "name LIKE ? ESCAPE E'\\\\'", name.to_escaped_for_sql_like + "%"
      end
    end
    
    return b.to_hash
  end
end
