class RemoveNotesFromArtists < ActiveRecord::Migration
  def self.up
    Artist.find(:all, :conditions => ["notes <> '' and notes is not null"]).each do |artist|
      page = WikiPage.find_by_title(artist.name)
      notes = artist.__send__(:read_attribute, :notes)
      
      if page
        page.update_attributes(:body => notes, :ip_addr => '127.0.0.1', :user_id => 1)
      else
        page = WikiPage.create(:title => artist.name, :body => notes, :ip_addr => '127.0.0.1', :user_id => 1)
      end
    end
    
    remove_column :artists, :notes
  end

  def self.down
    add_column :artists, :notes, :text, :default => "", :null => false
  end
end
