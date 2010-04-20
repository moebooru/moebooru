require File.dirname(__FILE__) + '/../test_helper'

class TagAliasControllerTest < ActionController::TestCase
  fixtures :users
  
  def test_all
    post :create, {:tag_alias => {:name => "a", :alias => "b"}}, {:user_id => 3}
    t = TagAlias.find_by_name("a")
    assert_not_nil(t)
    
    get :index
    assert_response :success

    # Can't easily test the update action. The daemon process does the actual work.
    # Anything we create inside this test is created within a transaction, so any database
    # connection outside of this one won't see any changes. We can disable transactional
    # fixtures but this interferes with other tests. Just assume the action works correctly
    # and test the logic of update in the unit tests.
  end
end
