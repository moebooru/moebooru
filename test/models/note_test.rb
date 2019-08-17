require "test_helper"

class NoteTest < ActiveSupport::TestCase
  fixtures :users, :posts

  def create_note(params)
    Note.create({ :post_id => 1, :user_id => 1, :x => 0, :y => 0, :width => 100, :height => 100, :is_active => true, :ip_addr => "127.0.0.1" }.merge(params))
  end

  def test_api
    note = create_note(:body => "hello")
    assert_nothing_raised do
      note.to_json
    end
    assert_nothing_raised do
      note.to_xml
    end
  end

  def test_versioning
    note = create_note(:body => "hello")

    note_v1 = NoteVersion.find_by(:note_id => note.id, :version => 1)
    assert_not_nil(note_v1)
    assert_equal("hello", note_v1.body)

    note.update(:body => "hello v2")
    note_v2 = NoteVersion.find_by(:note_id => note.id, :version => 2)
    assert_not_nil(note_v2)
    assert_equal("hello v2", note_v2.body)

    note.revert_to!(1)
    assert_equal(1, note.version)
    assert_equal("hello", note.body)
  end

  def test_locking
    Post.update(1, :is_note_locked => true)
    note = create_note(:body => "hello")
    assert_equal(true, note.errors.any?)
    assert_equal(0, Note.where(:post_id => 1).count)

    Post.update(1, :is_note_locked => false)
    note = create_note(:body => "hello")
    assert_equal(false, note.errors.any?)
    assert_equal(1, Note.where(:post_id => 1).count)

    Post.update(1, :is_note_locked => true)
    note.update(:body => "hello v2")
    assert_equal(true, note.errors.any?)
    assert_equal(1, Note.where(:post_id => 1).count)
    assert_equal("hello", Note.find_by(:post_id => 1).body)
  end

  def test_last_noted_at
    assert_nil(Post.find(1).last_noted_at)
    note_a = create_note(:body => "hello")
    # FIXME: .to_i currently used to take care of rounding of time (float).
    assert_equal(note_a.updated_at.to_i, Post.find(1).last_noted_at.to_i)

    sleep 2
    note_b = create_note(:body => "hello 2")
    assert_equal(note_b.updated_at.to_i, Post.find(1).last_noted_at.to_i)
  end
end
