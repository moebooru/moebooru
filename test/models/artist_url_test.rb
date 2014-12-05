require "test_helper"

class ArtistUrlTest < ActiveSupport::TestCase
  fixtures :users, :artists

  def test_normalize
    artist = Artist.create(:name => "yukie")
    url = ArtistUrl.create(:artist_id => artist.id, :url => nil)
    assert !url.valid?

    url = ArtistUrl.create(:artist_id => artist.id, :url => "http://monet.com")
    assert_equal("http://monet.com", url.url)
    assert_equal("http://monet.com", url.normalized_url)

    url = ArtistUrl.create(:artist_id => artist.id, :url => "http://monet.com/")
    assert_equal("http://monet.com/", url.url)
    assert_equal("http://monet.com/", url.normalized_url)

    url = ArtistUrl.create(:artist_id => artist.id, :url => "http://blog55.fc2.com/monet")
    assert_equal("http://blog55.fc2.com/monet", url.url)
    assert_equal("http://blog.fc2.com/monet", url.normalized_url)

    url = ArtistUrl.create(:artist_id => artist.id, :url => "http://blog-imgs-55.fc2.com/monet")
    assert_equal("http://blog-imgs-55.fc2.com/monet", url.url)
    assert_equal("http://blog.fc2.com/monet", url.normalized_url)

    url = ArtistUrl.create(:artist_id => artist.id, :url => "http://img55.pixiv.net/monet")
    assert_equal("http://img55.pixiv.net/monet", url.url)
    assert_equal("http://img.pixiv.net/monet", url.normalized_url)
  end
end
