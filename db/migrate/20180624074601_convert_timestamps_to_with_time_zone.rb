class ConvertTimestampsToWithTimeZone < ActiveRecord::Migration[5.2]
  COLUMNS = {
    ar_internal_metadata: [:created_at, :updated_at],
    artists: [:updated_at],
    bans: [:expires_at],
    batch_uploads: [:created_at],
    comments: [:created_at, :updated_at],
    dmails: [:created_at],
    favorites: [:created_at],
    flagged_post_details: [:created_at],
    forum_posts: [:created_at, :updated_at],
    histories: [:created_at],
    inlines: [:created_at],
    ip_bans: [:created_at, :expires_at],
    job_tasks: [:created_at, :updated_at],
    note_versions: [:created_at, :updated_at],
    notes: [:created_at, :updated_at],
    pools: [:created_at, :updated_at, :zip_created_at],
    post_tag_histories: [:created_at],
    posts: [:created_at, :last_commented_at, :last_noted_at, :index_timestamp, :updated_at],
    post_votes: [:updated_at],
    tags: [:cached_related_expires_on],
    user_logs: [:created_at],
    user_records: [:created_at],
    users: [:created_at, :last_logged_in_at, :last_forum_topic_read_at, :avatar_timestamp, :last_comment_read_at, :last_deleted_post_seen_at],
    wiki_page_versions: [:created_at, :updated_at],
    wiki_pages: [:created_at, :updated_at],
  }

  def up
    COLUMNS.each do |table, columns|
      change_table table do |t|
        columns.each do |column|
          t.change column, :timestamptz
        end
      end
    end
  end

  def down
    COLUMNS.each do |table, columns|
      change_table table do |t|
        columns.each do |column|
          t.change column, :timestamp
        end
      end
    end
  end
end
