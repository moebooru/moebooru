require File.dirname(__FILE__) + '/../test_helper'

class TagTest < ActiveSupport::TestCase
  def setup
    if CONFIG["enable_caching"]
      CACHE.flush_all
    end
    
    @test_number = 1
  end

  def create_tag(params = {})
    Tag.create({:post_count => 0, :cached_related => "", :cached_related_expires_on => Time.now, :tag_type => 0, :is_ambiguous => false}.merge(params))
  end
  
  def create_post(tags, params = {})
    post = Post.create({:user_id => 1, :score => 0, :source => "", :rating => "s", :width => 100, :height => 100, :ip_addr => '127.0.0.1', :updater_ip_addr => "127.0.0.1", :updater_user_id => 1, :tags => tags, :status => "active", :file => upload_jpeg("#{RAILS_ROOT}/test/mocks/test/test#{@test_number}.jpg")}.merge(params))
    @test_number += 1
    post
  end
  
  def test_api
    tag = create_tag(:name => "t1")
    assert_nothing_raised {tag.to_json}
    assert_nothing_raised {tag.to_xml}
  end
  
  def test_count_by_period
    p1 = create_post("tag1", :created_at => 10.days.ago)
    p2 = create_post("tag1")
    p3 = create_post("tag1 tag2")
    
    results = Tag.count_by_period(3.days.ago, Time.now).sort {|a, b| a["name"] <=> b["name"]}
    assert_equal("2", results[0]["post_count"])
    assert_equal("tag1", results[0]["name"])
    assert_equal("1", results[1]["post_count"])
    assert_equal("tag2", results[1]["name"])

    results = Tag.count_by_period(20.days.ago, 5.days.ago).sort {|a, b| a["name"] <=> b["name"]}
    assert_equal("1", results[0]["post_count"])
    assert_equal("tag1", results[0]["name"])
  end
  
  def test_find_or_create_by_name
    t = Tag.find_or_create_by_name("-ho-ge")
    assert_nil(Tag.find_by_name("-ho-ge"))
    assert_not_nil(Tag.find_by_name("ho-ge"))
    t = Tag.find_by_name("ho-ge")
    assert_equal(CONFIG["tag_types"]["General"], t.tag_type)
    assert(!t.is_ambiguous?, "Tag should not be ambiguous")
    
    t = Tag.find_or_create_by_name("ambiguous:ho-ge")
    t = Tag.find_by_name("ho-ge")
    assert_equal(CONFIG["tag_types"]["General"], t.tag_type)
    assert(t.is_ambiguous?, "Tag should be ambiguous")
    
    t = Tag.find_or_create_by_name("artist:ho-ge")
    t = Tag.find_by_name("ho-ge")
    assert_equal(CONFIG["tag_types"]["Artist"], t.tag_type)
    
    t = Tag.find_or_create_by_name("artist:mogemoge")
    t = Tag.find_by_name("mogemoge")
    assert_equal(CONFIG["tag_types"]["Artist"], t.tag_type)
  end
  
  def test_select_ambiguous
    Tag.find_or_create_by_name("ambiguous:moge")
    Tag.find_or_create_by_name("chichi")
    assert_equal([], Tag.select_ambiguous([]))
    assert_equal(["moge"], Tag.select_ambiguous(["moge", "chichi", "oppai"]))
  end
  
  if CONFIG["enable_caching"]
    def test_cache
      Tag.find_or_create_by_name("artist:a1")
      assert_equal("artist", Cache.get("tag_type:a1"))
    end
  end

  def test_parse_query
    results = Tag.parse_query("tag1 tag2")
    assert_equal(["tag1", "tag2"], results[:related])
    assert_equal([], results[:include])
    assert_equal([], results[:exclude])

    results = Tag.parse_query("tag1 -tag2")
    assert_equal(["tag1"], results[:related])
    assert_equal([], results[:include])
    assert_equal(["tag2"], results[:exclude])

    results = Tag.parse_query("tag1 ~tag2")
    assert_equal(["tag1"], results[:related])
    assert_equal(["tag2"], results[:include])
    assert_equal([], results[:exclude])
    
    results = Tag.parse_query("user:bof")
    assert_equal([], results[:related])
    assert_equal([], results[:include])
    assert_equal([], results[:exclude])
    assert_equal("bof", results[:user])
    
    results = Tag.parse_query("id:5")
    assert_equal([:eq, 5], results[:post_id])

    results = Tag.parse_query("id:5..")
    assert_equal([:gte, 5], results[:post_id])

    results = Tag.parse_query("id:..5")
    assert_equal([:lte, 5], results[:post_id])

    results = Tag.parse_query("id:5..10")
    assert_equal([:between, 5, 10], results[:post_id])
    
    # Test aliasing & implications
    tag_z = Tag.find_or_create_by_name("tag-z")
    TagAlias.create(:name => "tag-x", :alias_id => tag_z.id, :is_pending => false, :reason => "none", :creator_id => 1)
    tag_a = Tag.find_or_create_by_name("tag-a")
    tag_b = Tag.find_or_create_by_name("tag-b")
    TagImplication.create(:predicate_id => tag_a.id, :consequent_id => tag_b.id, :is_pending => false)
    
    results = Tag.parse_query("tag-x")
    assert_equal(["tag-z"], results[:related])

    results = Tag.parse_query("-tag-x")
    assert_equal(["tag-z"], results[:exclude])
    
    results = Tag.parse_query("tag-a")
    assert_equal(["tag-a"], results[:related])
  end
  
  def test_related
    p1 = create_post("tag1 tag2")
    p2 = create_post('tag1 tag2 tag3')
    
    t = Tag.find_by_name("tag1")
    related = t.related.sort {|a, b| a[0] <=> b[0]}
    assert_equal(["tag1", "2"], related[0])
    assert_equal(["tag2", "2"], related[1])
    assert_equal(["tag3", "1"], related[2])
    
    # Make sure the related tags are cached
    p3 = create_post("tag1 tag4")
    t.reload
    related = t.related.sort {|a, b| a[0] <=> b[0]}
    assert_equal(3, related.size)
    assert_equal(["tag1", "2"], related[0])
    assert_equal(["tag2", "2"], related[1])
    assert_equal(["tag3", "1"], related[2])
    
    # Make sure related tags are properly updated with the cache is expired
    t.update_attributes(:cached_related_expires_on => 5.days.ago)
    t.reload
    related = t.related.sort {|a, b| a[0] <=> b[0]}
    assert_equal(4, related.size)
    assert_equal(["tag1", "3"], related[0])
    assert_equal(["tag2", "2"], related[1])
    assert_equal(["tag3", "1"], related[2])
    assert_equal(["tag4", "1"], related[3])
  end
  
  def test_related_by_type
    p1 = create_post("tag1 artist:tag2")
    p2 = create_post('tag1 tag2 artist:tag3 copyright:tag4')
    
    related = Tag.calculate_related_by_type("tag1", CONFIG["tag_types"]["Artist"]).sort {|a, b| a["name"] <=> b["name"]}
    assert_equal(2, related.size)
    assert_equal("tag2", related[0]["name"])
    assert_equal("2", related[0]["post_count"])
    assert_equal("tag3", related[1]["name"])
    assert_equal("1", related[1]["post_count"])
  end
  
  def test_types
    t = Tag.find_or_create_by_name("artist:foo")
    assert_equal("artist", t.type_name)
  end
  
  def test_suggestions
    create_post("julius_caesar")
    create_post("julian")
    
    assert_equal(["julius_caesar"], Tag.find_suggestions("caesar_julius"))
    assert_equal(["julian", "julius_caesar"], Tag.find_suggestions("juli"))
  end
end
