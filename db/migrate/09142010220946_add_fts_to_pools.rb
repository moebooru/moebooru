class AddFtsToPools < ActiveRecord::Migration[5.1]
  def self.up
    execute "ALTER TABLE pools ADD COLUMN search_index tsvector"

    execute """
    CREATE OR REPLACE FUNCTION pools_search_update_trigger() RETURNS trigger AS $$
    BEGIN
      new.search_index := to_tsvector('pg_catalog.english', new.name || ' ' || new.description);
      RETURN new;
    END
    $$ LANGUAGE plpgsql;
    """

    execute "CREATE TRIGGER trg_pools_search_update BEFORE INSERT OR UPDATE ON pools
    FOR EACH ROW EXECUTE PROCEDURE pools_search_update_trigger()"
    execute "UPDATE pools set name=name"
    execute "CREATE INDEX post_search_idx on pools using gin(search_index)"
  end

  def self.down
    execute "ALTER TABLE pools DROP COLUMN search_index"
  end
end
