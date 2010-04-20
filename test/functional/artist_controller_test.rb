require File.dirname(__FILE__) + '/../test_helper'

class ArtistControllerTest < ActionController::TestCase
  fixtures :users
  
  def create_artist(name, params = {})
    Artist.create({:updater_id => 1, :updater_ip_addr => "127.0.0.1", :name => name}.merge(params))
  end

  def test_destroy
    artist = create_artist("bob")
    
    post :destroy, {:id => artist.id, :commit => "Yes"}, {:user_id => 1}
    assert_redirected_to :action => "index"
    assert_nil(Artist.find_by_name("bob"))
  end
  
  def test_update
    artist = create_artist("bob")
    
    get :update, {:id => artist.id}, {:user_id => 4}
    assert_response :success

    post :update, {:id => artist.id, :artist => {:name => "monet", :urls => "http://monet.com/home\nhttp://monet.com/links\n", :alias_names => "claude, oscar", :member_names => "john, mary", :notes => "Claude Oscar Monet"}}, {:user_id => 4}
    artist.reload
    assert_equal("monet", artist.name)
    monet = Artist.find_by_name("monet")
    assert_not_nil(monet)
    assert_redirected_to :controller => "artist", :action => "show", :id => monet.id
    claude = Artist.find_by_name("claude")
    assert_not_nil(claude)
    assert_equal(monet.id, claude.alias_id)
    oscar = Artist.find_by_name("oscar")
    assert_not_nil(oscar)
    john = Artist.find_by_name("john")
    assert_not_nil(john)
    assert_equal(monet.id, john.group_id)
    mary = Artist.find_by_name("mary")
    assert_not_nil(mary)
    assert_equal(["http://monet.com/home", "http://monet.com/links"], monet.artist_urls.map(&:url).sort)
  end
  
  def test_create
    get :create, {}, {:user_id => 4}
    assert_response :success
    
    post :create, {:artist => {:name => "monet", :urls => "http://monet.com/home\nhttp://monet.com/links\n", :alias_names => "claude, oscar", :member_names => "john, mary", :notes => "Claude Oscar Monet"}}, {:user_id => 4}
    monet = Artist.find_by_name("monet")
    assert_not_nil(monet)
    assert_redirected_to :controller => "artist", :action => "show", :id => monet.id
    claude = Artist.find_by_name("claude")
    assert_not_nil(claude)
    assert_equal(monet.id, claude.alias_id)
    oscar = Artist.find_by_name("oscar")
    assert_not_nil(oscar)
    john = Artist.find_by_name("john")
    assert_not_nil(john)
    assert_equal(monet.id, john.group_id)
    mary = Artist.find_by_name("mary")
    assert_not_nil(mary)
    assert_equal(["http://monet.com/home", "http://monet.com/links"], monet.artist_urls.map(&:url).sort)
  end
  
  def test_show
    monet = create_artist("monet")
    get :show, {:id => monet.id}
    assert_response :success
  end
  
  def test_index
    create_artist("monet")
    create_artist("pablo", :alias_name => "monet")
    create_artist("hanaharu", :group_name => "monet")
    get :index
    assert_response :success
    
    # TODO: add additional cases
  end
end
