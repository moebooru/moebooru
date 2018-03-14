class AddSafePostCountToTags < ActiveRecord::Migration[5.1]
  def self.up
    execute "ALTER TABLE tags ADD COLUMN safe_post_count INTEGER NOT NULL DEFAULT 0"
    execute "UPDATE tags SET safe_post_count = (SELECT COUNT(*) FROM posts p, posts_tags pt WHERE p.id = pt.post_id AND pt.tag_id = tags.id AND p.rating = 's')"
    execute "DROP TRIGGER trg_posts_tags__delete ON posts_tags"
    execute "DROP TRIGGER trg_posts_tags__insert ON posts_tags"
    execute "INSERT INTO table_data (name, row_count) VALUES ('safe_posts', (SELECT COUNT(*) FROM posts WHERE rating = 's'))"
    execute <<-EOS
      CREATE OR REPLACE FUNCTION trg_posts_tags__delete() RETURNS "trigger" AS $$
      BEGIN
        UPDATE tags SET post_count = post_count - 1 WHERE tags.id = OLD.tag_id;
        UPDATE tags SET safe_post_count = safe_post_count - 1 FROM posts WHERE tags.id = OLD.tag_id AND OLD.post_id = posts.id AND posts.rating = 's';
        RETURN OLD;
      END;
      $$ LANGUAGE plpgsql;
    EOS
    execute <<-EOS
      CREATE OR REPLACE FUNCTION trg_posts_tags__insert() RETURNS "trigger" AS $$
      BEGIN
        UPDATE tags SET post_count = post_count + 1 WHERE tags.id = NEW.tag_id;
        UPDATE tags SET safe_post_count = safe_post_count + 1 FROM posts WHERE tags.id = NEW.tag_id AND NEW.post_id = posts.id AND posts.rating = 's';
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;
    EOS
    execute "CREATE TRIGGER trg_posts_tags__delete BEFORE DELETE ON posts_tags FOR EACH ROW EXECUTE PROCEDURE trg_posts_tags__delete()"
    execute "CREATE TRIGGER trg_posts_tags__insert BEFORE INSERT ON posts_tags FOR EACH ROW EXECUTE PROCEDURE trg_posts_tags__insert()"
  end

  def self.down
    execute "ALTER TABLE tags DROP COLUMN safe_post_count"
    execute "DROP TRIGGER trg_posts_tags__delete ON posts_tags"
    execute "DROP TRIGGER trg_posts_tags__insert ON posts_tags"
    execute <<-EOS
      CREATE OR REPLACE FUNCTION trg_posts_tags__delete() RETURNS "trigger" AS $$
      BEGIN
        UPDATE tags SET post_count = post_count - 1 WHERE tags.id = OLD.tag_id;
        RETURN OLD;
      END;
      $$ LANGUAGE plpgsql;
    EOS
    execute <<-EOS
      CREATE OR REPLACE FUNCTION trg_posts_tags__insert() RETURNS "trigger" AS $$
      BEGIN
        UPDATE tags SET post_count = post_count + 1 WHERE tags.id = NEW.tag_id;
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;
    EOS
    execute "CREATE TRIGGER trg_posts_tags__delete BEFORE DELETE ON posts_tags FOR EACH ROW EXECUTE PROCEDURE trg_posts_tags__delete()"
    execute "CREATE TRIGGER trg_posts_tags__insert BEFORE INSERT ON posts_tags FOR EACH ROW EXECUTE PROCEDURE trg_posts_tags__insert()"
  end
end
