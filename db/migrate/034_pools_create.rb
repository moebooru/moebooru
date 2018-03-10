class PoolsCreate < ActiveRecord::Migration[5.1]
  def self.up
    ActiveRecord::Base.transaction do
      execute <<-EOS
        CREATE TABLE pools (
          id SERIAL PRIMARY KEY,
          name TEXT NOT NULL,
          created_at TIMESTAMP NOT NULL,
          updated_at TIMESTAMP NOT NULL,
          user_id INTEGER NOT NULL REFERENCES users ON DELETE CASCADE,
          is_public BOOLEAN NOT NULL DEFAULT FALSE,
          post_count INTEGER NOT NULL DEFAULT 0,
          description TEXT NOT NULL DEFAULT ''
        )
      EOS
      execute <<-EOS
        CREATE TABLE pools_posts (
          id SERIAL PRIMARY KEY,
          sequence INTEGER NOT NULL DEFAULT 0,
          pool_id INTEGER NOT NULL REFERENCES pools ON DELETE CASCADE,
          post_id INTEGER NOT NULL REFERENCES posts ON DELETE CASCADE
        )
      EOS
      execute <<-EOS
        CREATE OR REPLACE FUNCTION pools_posts_delete_trg() RETURNS "trigger" AS $$
        BEGIN
          UPDATE pools SET post_count = post_count - 1 WHERE id = OLD.pool_id;
          RETURN OLD;
        END;
        $$ LANGUAGE plpgsql;
      EOS
      execute <<-EOS
        CREATE OR REPLACE FUNCTION pools_posts_insert_trg() RETURNS "trigger" AS $$
        BEGIN
          UPDATE pools SET post_count = post_count + 1 WHERE id = NEW.pool_id;
          RETURN NEW;
        END;
        $$ LANGUAGE plpgsql;
      EOS
      execute <<-EOS
        CREATE TRIGGER pools_posts_insert_trg
            BEFORE INSERT ON pools_posts
            FOR EACH ROW
            EXECUTE PROCEDURE pools_posts_insert_trg();
      EOS
      execute <<-EOS
        CREATE TRIGGER pools_posts_delete_trg
            BEFORE DELETE ON pools_posts
            FOR EACH ROW
            EXECUTE PROCEDURE pools_posts_delete_trg();
      EOS
      execute <<-EOS
        CREATE INDEX pools_user_id_idx ON pools (user_id)
      EOS
      execute <<-EOS
        CREATE INDEX pools_posts_pool_id_idx ON pools_posts (pool_id)
      EOS
      execute <<-EOS
        CREATE INDEX pools_posts_post_id_idx ON pools_posts (post_id)
      EOS
    end
  end

  def self.down
    ActiveRecord::Base.transaction do
      execute "DROP TABLE pools_posts"
      execute "DROP TABLE pools"
      execute "DROP FUNCTION pools_posts_insert_trg()"
      execute "DROP FUNCTION pools_posts_delete_trg()"
    end
  end
end
