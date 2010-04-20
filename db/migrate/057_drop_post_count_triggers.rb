class DropPostCountTriggers < ActiveRecord::Migration
  def self.up
    execute "drop trigger trg_posts__insert on posts"
    execute "drop trigger trg_posts_delete on posts"
    execute "drop function trg_posts__insert()"
    execute "drop function trg_posts__delete()"
    execute "drop trigger trg_users_delete on users"
    execute "drop trigger trg_users_insert on users"
    execute "drop function trg_users__delete()"
    execute "drop function trg_users__insert()"
    execute "insert into table_data (name, row_count) values ('non-explicit_posts', (select count(*) from posts where rating <> 'e'))"
    execute "delete from table_data where name = 'safe_posts'"
    execute "drop trigger trg_posts_tags__delete on posts_tags"
    execute "drop trigger trg_posts_tags__insert on posts_tags"
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
    execute "alter table tags drop column safe_post_count"
  end

  def self.down
    raise IrreversibleMigration
  end
end
