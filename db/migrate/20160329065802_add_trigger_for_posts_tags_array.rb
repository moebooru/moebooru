class AddTriggerForPostsTagsArray < ActiveRecord::Migration[5.1]
  def up
    execute <<-SQL.strip_heredoc
      CREATE OR REPLACE FUNCTION posts_tags_array_update() RETURNS trigger AS $$
      BEGIN
        IF (TG_OP = 'INSERT') OR (NEW.cached_tags <> OLD.cached_tags) THEN
          NEW.tags_array := string_to_array(NEW.cached_tags, ' ');
        END IF;

        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;

      CREATE TRIGGER posts_tags_array_update
      BEFORE INSERT OR UPDATE ON posts
      FOR EACH ROW EXECUTE PROCEDURE posts_tags_array_update();
    SQL

    add_index :posts, :tags_array, :using => :gin
  end

  def down
    execute <<-SQL.strip_heredoc
      DROP TRIGGER posts_tags_array_update ON posts;
      DROP FUNCTION posts_tags_array_update();
    SQL

    remove_index :posts, :tags_array
  end
end
