require "post"

class ConvertFavoritesToVotes < ActiveRecord::Migration[5.1]
  def self.up
    # Favorites doesn't have a dupe constraint and post_votes does, so make sure
    # there are no dupes before we copy.
    execute "DELETE FROM favorites " \
            "WHERE id IN (" \
              "SELECT f.id FROM favorites f, favorites f2 " \
              " WHERE f.user_id = f2.user_id AND " \
              "       f.post_id = f2.post_id AND " \
              "       f.id <> f2.id AND f.id > f2.id)"
    execute "DELETE FROM post_votes pv WHERE pv.id IN " \
            "  (SELECT pv.id FROM post_votes pv JOIN favorites f ON (pv.user_id = f.user_id AND pv.post_id = f.post_id))"
    execute "INSERT INTO post_votes (user_id, post_id, score, updated_at) " \
            " SELECT f.user_id, f.post_id, 3, f.created_at FROM favorites f"
    p Post
    debugger
    Post.recalculate_score
  end

  def self.down
  end
end
