namespace :maint do
  desc "fix_tags"
  task fix_tags: :environment do
    # Fix post counts
    Tag.recalculate_post_count

    # Fix cached tags
    Post.recalculate_cached_tags

    Post.recalculate_has_children
  end

  desc "Recalculate post counts"
  task recalculate_row_count: :environment do
    Post.recalculate_row_count
  end

  desc "Purge unused tags"
  task purge_tags: :environment do
    Tag.purge_tags
  end

  desc "Username case fix"
  task username_case: :environment do
    User.find_in_batches do |users|
      users.each do |user|
        user.update name_normalized: user.name.downcase
      end
    end
  end
end
