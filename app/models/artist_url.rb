class ArtistUrl < ActiveRecord::Base
  before_save :normalize
  validates_presence_of :url

  def self.normalize(url)
    if url.nil?
      return nil
    else
      url = url.gsub(/^http:\/\/blog\d+\.fc2/, "http://blog.fc2")
      url = url.gsub(/^http:\/\/blog-imgs-\d+\.fc2/, "http://blog.fc2")
      # Pixiv pre-2012
      # Example URL: http://img55.pixiv.net/img/kazamatuli/16634039.jpg
      url = url.gsub(/^http:\/\/img\d+\.pixiv\.net/, "http://img.pixiv.net")
      # Pixiv 2012
      # Example URL: http://i1.pixiv.net/img55/img/kazamatuli/29701368.jpg
      url = url.gsub(/^http:\/\/i\d+\.pixiv\.net\/img\d+/, "http://img.pixiv.net")
      return url
    end
  end

  def self.normalize_for_search(url)
    if url =~ /\.\w+$/ && url =~ /\w\/\w/
      url = File.dirname(url)
    end

    url.gsub(/^http:\/\/blog\d+\.fc2/, "http://blog*.fc2")
      .gsub(/^http:\/\/blog-imgs-\d+\.fc2/, "http://blog*.fc2")
      .gsub(/^http:\/\/img\d+\.pixiv\.net/, "http://img*.pixiv.net")
      .gsub(/^http:\/\/i\d+\.pixiv\.net\/img\d+/, "http://img*.pixiv.net")
  end

  def normalize
    self.normalized_url = self.class.normalize(url)
  end
end
