class AddHistoryTable < ActiveRecord::Migration[5.1]
  def self.up
    execute <<-EOS
      CREATE TABLE history_changes (
        id SERIAL PRIMARY KEY,
        field TEXT NOT NULL,
        remote_id INTEGER NOT NULL,
        table_name TEXT NOT NULL,
        value TEXT,
        history_id INTEGER NOT NULL,
        previous_id INTEGER
      )
    EOS

    execute <<-EOS
      CREATE TABLE histories (
        id SERIAL PRIMARY KEY,
        created_at TIMESTAMP NOT NULL DEFAULT now(),
        user_id INTEGER,
        group_by_id INTEGER NOT NULL,
        group_by_table TEXT NOT NULL
      )
    EOS

    # cleanup_history entries can be deleted by a rule (see update_versioned_tables).  When
    # the last change for a history is deleted, delete the history, so it doesn't show up
    # as an empty line in the history list.
    execute <<-EOS
      CREATE OR REPLACE FUNCTION trg_purge_histories() RETURNS "trigger" AS $$
      BEGIN
        DELETE FROM histories h WHERE h.id = OLD.history_id AND
          (SELECT COUNT(*) FROM history_changes hc WHERE hc.history_id = OLD.history_id LIMIT 1) = 0;
        RETURN OLD;
      END;
      $$ LANGUAGE plpgsql;
    EOS
    execute "CREATE TRIGGER trg_cleanup_history AFTER DELETE ON history_changes FOR EACH ROW EXECUTE PROCEDURE trg_purge_histories()"

    add_foreign_key :history_changes, :history_id, :histories, :id, :on_delete => :cascade
    add_foreign_key :history_changes, :previous_id, :history_changes, :id, :on_delete => :set_null

    add_index :histories, :group_by_table
    add_index :histories, :group_by_id
    add_index :histories, :user_id
    add_index :histories, :created_at
    add_index :history_changes, :table_name
    add_index :history_changes, :remote_id
    add_index :history_changes, :history_id

    add_column :pools_posts, :active, :boolean, :default => true, :null => false
    add_index :pools_posts, :active
  end

  def self.down
    execute "DROP TABLE history_changes CASCADE"
    execute "DROP TABLE histories"
    remove_column :pools_posts, :active
  end
end
