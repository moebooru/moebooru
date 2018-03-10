class UpdatePoolCountTriggers < ActiveRecord::Migration[5.1]
  def self.up
    execute <<-EOS
      CREATE OR REPLACE FUNCTION pools_posts_delete_trg() RETURNS "trigger" AS $$
      BEGIN
        IF (OLD.active) THEN
          UPDATE pools SET post_count = post_count - 1 WHERE id = OLD.pool_id;
        END IF;
        RETURN OLD;
      END;
      $$ LANGUAGE plpgsql;
    EOS

    execute <<-EOS
      CREATE OR REPLACE FUNCTION pools_posts_insert_trg() RETURNS "trigger" AS $$
      BEGIN
        IF (NEW.active) THEN
          UPDATE pools SET post_count = post_count + 1 WHERE id = NEW.pool_id;
        END IF;
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;
    EOS

    execute <<-EOS
      CREATE OR REPLACE FUNCTION pools_posts_update_trg() RETURNS "trigger" AS $$
      BEGIN
        IF (OLD.active <> NEW.active) THEN
          IF (NEW.active) THEN
            UPDATE pools SET post_count = post_count + 1 WHERE id = NEW.pool_id;
          ELSE
            UPDATE pools SET post_count = post_count - 1 WHERE id = NEW.pool_id;
          END IF;
        END IF;
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;
    EOS

    execute <<-EOS
      CREATE TRIGGER pools_posts_update_trg
      BEFORE UPDATE ON pools_posts
      FOR EACH ROW EXECUTE PROCEDURE pools_posts_update_trg();
    EOS
  end

  def self.down
    raise IrreversibleMigration
  end
end
