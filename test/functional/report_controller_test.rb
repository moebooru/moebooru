require File.dirname(__FILE__) + '/../test_helper'

class ReportControllerTest < ActionController::TestCase
  fixtures :users
  
  def create_post(tags, post_number = 1, params = {})
    Post.create({:user_id => 1, :score => 0, :source => "", :rating => "s", :width => 100, :height => 100, :ip_addr => '127.0.0.1', :updater_ip_addr => "127.0.0.1", :updater_user_id => 1, :tags => tags, :status => "active", :file => upload_jpeg("#{RAILS_ROOT}/test/mocks/test/test#{post_number}.jpg")}.merge(params))
  end
  
  def update_post(post, params = {})
    post.update_attributes({:updater_user_id => 1, :updater_ip_addr => '127.0.0.1'}.merge(params))
  end

  def create_note(params = {})
    Note.create({:post_id => 1, :user_id => 1, :x => 0, :y => 0, :width => 100, :height => 100, :is_active => true, :ip_addr => "127.0.0.1"}.merge(params))
  end
  
  def create_wiki(params = {})
    WikiPage.create({:title => "hoge", :user_id => 1, :body => "hoge", :ip_addr => "127.0.0.1", :is_locked => false}.merge(params))
  end
  
  def test_tag_changes
    p1 = create_post("hoge", 1)
    update_post(p1, :tags => "moge")
    
    get :tag_changes, {}, {}
    assert_response :success
  end
  
  def test_note_changes
    n1 = create_note(:body => "hoge")
    n1.update_attributes(:body => "moge")
    
    get :note_changes, {}, {}
    assert_response :success
  end
  
  def test_wiki_changes
    w1 = create_wiki
    w1.update_attributes(:body => "moge")
    
    get :wiki_changes, {}, {}
    assert_response :success
  end
end
