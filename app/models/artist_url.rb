class ArtistUrl < ActiveRecord::Base
  before_save :normalize
  validates_presence_of :url
  
  def self.normalize(url)
    if url.nil?
      return nil
    else
      url = url.gsub(/^http:\/\/blog\d+\.fc2/, "http://blog.fc2")
      url = url.gsub(/^http:\/\/blog-imgs-\d+\.fc2/, "http://blog.fc2")
      url = url.gsub(/^http:\/\/img\d+\.pixiv\.net/, "http://img.pixiv.net")
      return url
    end
  end
  
  def self.normalize_for_search(url)
    if url =~ /\.\w+$/ && url =~ /\w\/\w/
      url = File.dirname(url)
    end
    
    url = url.gsub(/^http:\/\/blog\d+\.fc2/, "http://blog*.fc2")
    url = url.gsub(/^http:\/\/blog-imgs-\d+\.fc2/, "http://blog*.fc2")
    url = url.gsub(/^http:\/\/img\d+\.pixiv\.net/, "http://img*.pixiv.net")    
  end

  def normalize
    self.normalized_url = self.class.normalize(self.url)
  end
end
