class ArtistUrl < ApplicationRecord
  before_save :normalize
  validates_presence_of :url

  def self.normalize(url)
    return unless url

    url
      .gsub(%r{\Ahttps?://}, "http://")
      .gsub(/^http:\/\/blog\d+\.fc2/, "http://blog.fc2")
      .gsub(/^http:\/\/blog-imgs-\d+\.fc2/, "http://blog.fc2")
      .gsub(/^https?:\/\/img\d+\.pixiv\.net/, "http://img.pixiv.net") # [1]
      .gsub(/^https?:\/\/i\d+\.pixiv\.net\/img\d+/, "http://img.pixiv.net") # [2]
    # [1] pixiv pre-2012. Example URL: http://img55.pixiv.net/img/kazamatuli/16634039.jpg
    # [2] pixiv 2012. Example URL: http://i1.pixiv.net/img55/img/kazamatuli/29701368.jpg
  end

  def self.normalize_for_search(url)
    if url =~ /\.\w+$/ && url =~ /\w\/\w/
      url = File.dirname(url)
    end

    url
      .gsub(%r{\Ahttps?://}, "http://")
      .gsub(/^http:\/\/blog\d+\.fc2/, "http://blog*.fc2")
      .gsub(/^http:\/\/blog-imgs-\d+\.fc2/, "http://blog*.fc2")
      .gsub(/^https?:\/\/img\d+\.pixiv\.net/, "http://img*.pixiv.net")
      .gsub(/^https?:\/\/i\d+\.pixiv\.net\/img\d+/, "http://img*.pixiv.net")
  end

  def normalize
    self.normalized_url = self.class.normalize(url)
  end
end
