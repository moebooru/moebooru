class PostsTagsAddForeignKeys < ActiveRecord::Migration[5.1]
  def self.up
    transaction do
      execute "update tags set post_count = (select count(*) from posts_tags pt where pt.tag_id = tags.id)"
      execute "update tags set safe_post_count = (select count(*) from posts_tags pt, posts p where pt.tag_id = tags.id and pt.post_id = p.id and p.rating = 's')"

      execute "alter table posts_tags add constraint fk_posts_tags__post foreign key (post_id) references posts on delete cascade"
      execute "alter table posts_tags add constraint fk_posts_tags__tag foreign key (tag_id) references tags on delete cascade"
    end
  end

  def self.down
    begin
      execute "alter table posts_tags drop constraint fk_posts_tags__post"
    rescue
    end

    begin
      execute "alter table posts_tags drop constraint fk_posts_tags__tag"
    rescue
    end
  end
end
