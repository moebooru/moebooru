class PostsTagsFixForeignKeys < ActiveRecord::Migration
  def self.up
    begin
      execute "alter table posts_tags add constraint fk_posts_tags__post foreign key (post_id) references posts on delete cascade"
    rescue Exception
    end

    begin
      execute "alter table posts_tags add constraint fk_posts_tags__tag foreign key (tag_id) references tags on delete cascade"
    rescue Exception
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
