require "test_helper"

class WikiPageTest < ActiveSupport::TestCase
  def create_wiki(params = {})
    WikiPage.create({ :title => "hoge", :user_id => 1, :body => "hoge", :ip_addr => "127.0.0.1", :is_locked => false }.merge(params))
  end

  def update_wiki(w1, params = {})
    w1.update(params)
  end

  def test_normalize
    w1 = create_wiki(:title => "HOT POTATO")
    assert_equal("hot_potato", w1.title)
  end

  def test_diff
    # Still don't really understand the logic here
    w1 = create_wiki(:body => "hoge")
    update_wiki(w1, :body => "moge")
    assert_equal("<del>moge</del><ins>hoge</ins>", w1.diff(1))

    w2 = create_wiki(:body => "hoge")
    update_wiki(w2, :body => "moge hoge")
    assert_equal("<del>moge </del>hoge", w2.diff(1))

    # w3 = create_wiki(:body => "<h1>hoge</h1> <p>moge</p>")
    # update_wiki(w3, :body => "<h2>hoge</h2> <p>moge</p>")
    # assert_equal("<del>&lt;h2&gt;</del>hoge<del>&lt;/h2&gt; &lt;p&gt;moge&lt;/p&gt;</del>", w3.diff(1))
  end

  def test_find_page
    w1 = create_wiki
    update_wiki(w1, :body => "moge")
    update_wiki(w1, :body => "moge moge")

    w1 = WikiPage.find_page("hoge", 1)
    assert_equal("hoge", w1.body)

    w1 = WikiPage.find_page("hoge", 2)
    assert_equal("moge", w1.body)

    w1 = WikiPage.find_page("hoge", 3)
    assert_equal("moge moge", w1.body)
  end

  def test_lock
    w1 = create_wiki
    update_wiki(w1, :body => "moge")
    update_wiki(w1, :body => "moge moge")

    w1.lock!
    assert_equal(true, w1.is_locked?)
    assert_equal(true, WikiPageVersion.find_by(:wiki_page_id => w1.id, :version => 1).is_locked?)
    assert_equal(true, WikiPageVersion.find_by(:wiki_page_id => w1.id, :version => 2).is_locked?)

    w1.unlock!
    assert_equal(false, w1.is_locked?)
    assert_equal(false, WikiPageVersion.find_by(:wiki_page_id => w1.id, :version => 1).is_locked?)
    assert_equal(false, WikiPageVersion.find_by(:wiki_page_id => w1.id, :version => 2).is_locked?)
  end

  def test_rename
    w1 = create_wiki
    update_wiki(w1, :body => "moge")
    update_wiki(w1, :body => "moge moge")

    w1.rename!("shalala")
    assert_not_nil(WikiPageVersion.find_by_title("shalala"))
  end

  def test_api
    w1 = create_wiki
    assert_nothing_raised { w1.to_json }
    assert_nothing_raised { w1.to_xml }
  end
end
