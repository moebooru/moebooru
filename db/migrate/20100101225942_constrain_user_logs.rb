class ConstrainUserLogs < ActiveRecord::Migration[5.1]
  def self.up
    execute <<-EOS
      CREATE TEMPORARY TABLE user_logs_new (
        id SERIAL PRIMARY KEY,
        user_id integer NOT NULL,
        created_at timestamp NOT NULL DEFAULT now(),
        ip_addr inet NOT NULL,
        CONSTRAINT user_logs_new_user_ip UNIQUE (user_id, ip_addr)
      )
    EOS

    execute <<-EOS
      INSERT INTO user_logs_new (user_id, ip_addr, created_at)
      SELECT user_id, ip_addr, MAX(created_at) FROM user_logs GROUP BY user_id, ip_addr;
    EOS

    execute "DELETE FROM user_logs;"

    execute <<-EOS
      INSERT INTO user_logs (user_id, ip_addr, created_at)
      SELECT user_id, ip_addr, created_at FROM user_logs_new;
    EOS

    # Make user_logs user/ip pairs unique.
    execute "ALTER TABLE user_logs ADD CONSTRAINT user_logs_user_ip UNIQUE (user_id, ip_addr);"

    # If a log for a user/ip pair exists, update its timestamp.  Otherwise, create a new
    # record.  Updating an existing record is the fast path.
    execute <<-EOS
      CREATE OR REPLACE FUNCTION user_logs_touch(new_user_id integer, new_ip inet) RETURNS VOID AS $$
      BEGIN
        FOR i IN 1..3 LOOP
          UPDATE user_logs SET created_at = now() where user_id = new_user_id and ip_addr = new_ip;
          IF found THEN
            RETURN;
          END IF;

          BEGIN
            INSERT INTO user_logs (user_id, ip_addr) VALUES (new_user_id, new_ip);
            RETURN;
          EXCEPTION WHEN unique_violation THEN
            -- Try again.
          END;
        END LOOP;
      END;
      $$ LANGUAGE plpgsql;
    EOS
  end

  def self.down
    execute "ALTER TABLE user_logs DROP CONSTRAINT user_logs_user_ip;"
    execute "DROP FUNCTION user_logs_touch(integer, inet);"
  end
end
