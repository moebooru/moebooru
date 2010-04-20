require File.dirname(__FILE__) + '/../test_helper'

class ArtistTest < ActiveSupport::TestCase
  fixtures :users
  
  def setup
    if CONFIG["enable_caching"]
      CACHE.flush_all
    end
  end
  
  def create_artist(params)
    Artist.create({:updater_id => 1, :updater_ip_addr => "127.0.0.1"}.merge(params))
  end
  
  def update_artist(artist, params)
    artist.update_attributes({:updater_id => 1, :updater_ip_addr => "127.0.0.1"}.merge(params))
  end
  
  def test_normalize
    artist = create_artist(:name => "pierre")
    assert_equal("pierre", artist.name)
    
    # Test downcasing of name
    artist = create_artist(:name => "JACQUES")
    assert_equal("jacques", artist.name)
    
    # Delete leading and trailing whitespace
    artist = create_artist(:name => " monet ")
    assert_equal("monet", artist.name)
    
    # Convert whitespace to underscores
    artist = create_artist(:name => "takashi takeuchi")
    assert_equal("takashi_takeuchi", artist.name)
  end
  
  def test_urls
    artist = create_artist(:name => "rembrandt", :urls => "http://rembrandt.com/test.jpg")
    artist.reload
    assert_equal(["http://rembrandt.com/test.jpg"], artist.urls.split.sort)

    # Make sure old URLs are deleted, and make sure the artist understands multiple URLs
    update_artist(artist, :urls => "http://not.rembrandt.com/test.jpg\nhttp://also.not.rembrandt.com/test.jpg")
    artist.reload
    assert_equal(["http://also.not.rembrandt.com/test.jpg", "http://not.rembrandt.com/test.jpg"], artist.urls.split.sort)

    # Test Artist.find_all_by_url
    assert_equal(["rembrandt"], Artist.find_all_by_url("http://also.not.rembrandt.com/test.jpg").map(&:name))
    assert_equal(["rembrandt"], Artist.find_all_by_url("http://also.not.rembrandt.com/another.jpg").map(&:name))    
    assert_equal(["rembrandt"], Artist.find_all_by_url("http://not.rembrandt.com/another.jpg").map(&:name))    
    assert_equal([], Artist.find_all_by_url("http://nonexistent.rembrandt.com/test.jpg").map(&:name))

    # Make sure duplicates are removed
    create_artist(:name => "warhol", :urls => "http://warhol.com/a/image.jpg\nhttp://warhol.com/b/image.jpg")
    assert_equal(["warhol"], Artist.find_all_by_url("http://warhol.com/test.jpg").map(&:name))
  end
  
  def test_aliases_simple
    # Test to make sure setting an alias creates an artist if it doesn't already exist
    a1 = create_artist(:name => "a1", :alias_names => "initialg")
    assert_not_nil(Artist.find_by_name("a1"))
    assert_not_nil(Artist.find_by_name("initialg"))
    assert_equal(a1.id, Artist.find_by_name("initialg").alias_id)
  end

  def test_aliases_clear_out_old_aliases
    # Test to make sure setting an alias clears out any old aliases
    a1 = create_artist(:name => "a1", :alias_names => "initial-g")
    assert_equal(a1.id, Artist.find_by_name("initial-g").alias_id)
  end

  def test_aliases_removed_from_find_all_by_url
    # Test to make sure aliases are removed from Artist.find_all_by_url
    create_artist(:name => "amadeus", :urls => "http://amadeus.com/top.jpg")
    create_artist(:name => "mozart", :alias_names => "amadeus", :urls => "http://amadeus.com/top.jpg")
    matches = Artist.find_all_by_url("http://amadeus.com/top.jpg")
    assert_equal(1, matches.size)
    assert_equal("mozart", matches[0].name)
  end
  
  def test_groups
    cat_or_fish = create_artist(:name => "cat_or_fish", :member_names => "yuu, kazuki")
    yuu = Artist.find_by_name("yuu")
    kazuki = Artist.find_by_name("kazuki")
    assert_not_nil(yuu)
    assert_not_nil(kazuki)
    assert_equal(cat_or_fish.id, yuu.group_id)
    assert_equal(cat_or_fish.id, kazuki.group_id)
    
    max = create_artist(:name => "max", :group_name => "cat_or_fish")
    assert_equal(cat_or_fish.id, max.group_id)
    
    cat_or_fish.reload
    assert_equal([yuu.id, kazuki.id, max.id].sort, cat_or_fish.members.map(&:id).sort)
  end
  
  def test_api
    boss = create_artist(:name => "boss")
    assert_nothing_raised do
      boss.to_xml
    end
    assert_nothing_raised do
      boss.to_json
    end
  end
  
  def test_notes
    hoge = create_artist(:name => "hoge", :notes => "this is hoge")
    assert_not_nil(WikiPage.find_by_title("hoge"))
    assert_equal("this is hoge", WikiPage.find_by_title("hoge").body)
    
    update_artist(hoge, :notes => "this is hoge mark ii")
    assert_equal("this is hoge mark ii", WikiPage.find_by_title("hoge").body)
    
    WikiPage.find_by_title("hoge").lock!
    update_artist(hoge, :notes => "this is hoge mark iii")
    assert_equal("this is hoge mark ii", WikiPage.find_by_title("hoge").body)
  end
end
