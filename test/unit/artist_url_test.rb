require File.dirname(__FILE__) + '/../test_helper'

class ArtistUrlTest < ActiveSupport::TestCase
  fixtures :users, :artists
  
  def setup
    if CONFIG["enable_caching"]
      CACHE.flush_all
    end
  end
  
  def test_normalize
    url = ArtistUrl.create(:artist_id => 1, :url => nil)
    assert !url.valid?
    
    url = ArtistUrl.create(:artist_id => 1, :url => "http://monet.com")
    assert_equal("http://monet.com", url.url)
    assert_equal("http://monet.com", url.normalized_url)

    url = ArtistUrl.create(:artist_id => 1, :url => "http://monet.com/")
    assert_equal("http://monet.com/", url.url)
    assert_equal("http://monet.com/", url.normalized_url)

    url = ArtistUrl.create(:artist_id => 1, :url => "http://blog55.fc2.com/monet")
    assert_equal("http://blog55.fc2.com/monet", url.url)
    assert_equal("http://blog.fc2.com/monet", url.normalized_url)

    url = ArtistUrl.create(:artist_id => 1, :url => "http://blog-imgs-55.fc2.com/monet")
    assert_equal("http://blog-imgs-55.fc2.com/monet", url.url)
    assert_equal("http://blog.fc2.com/monet", url.normalized_url)

    url = ArtistUrl.create(:artist_id => 1, :url => "http://img55.pixiv.net/monet")
    assert_equal("http://img55.pixiv.net/monet", url.url)
    assert_equal("http://img.pixiv.net/monet", url.normalized_url)
  end
end
