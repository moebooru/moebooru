class PostsTagsAddForeignKeys < ActiveRecord::Migration
  def self.up
    transaction do
      execute "update tags set post_count = (select count(*) from posts_tags pt where pt.tag_id = tags.id)"
      execute "update tags set safe_post_count = (select count(*) from posts_tags pt, posts p where pt.tag_id = tags.id and pt.post_id = p.id and p.rating = 's')"

      begin
        execute "alter table posts_tags add constraint fk_posts_tags__post foreign key (post_id) references posts on delete cascade"
      rescue Exception
      end

      begin
        execute "alter table posts_tags add constraint fk_posts_tags__tag foreign key (tag_id) references tags on delete cascade"
      rescue Exception
      end
    end
  end

  def self.down
    begin
      execute "alter table posts_tags drop constraint fk_posts_tags__post"
    rescue Exception
    end

    begin
      execute "alter table posts_tags drop constraint fk_posts_tags__tag"
    rescue Exception
    end
  end
end
