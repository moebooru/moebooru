class  FixFtsUnderscores < ActiveRecord::Migration[5.1]
  def self.up
    execute """
      CREATE OR REPLACE FUNCTION replace_underscores(s varchar) RETURNS varchar IMMUTABLE AS $$
        BEGIN
          RETURN regexp_replace(s, '_', ' ', 'g');
        END;
      $$ LANGUAGE plpgsql;
    """

    # The name column has spaces replaced with underscores (for some reason).  Change them back
    # to spaces before passing it to to_tsvector, so it doesn't confuse the parser; for example,
    # things like "foo._bar" are parsed as filenames.
    execute """
      CREATE OR REPLACE FUNCTION pools_search_update_trigger() RETURNS trigger AS $$
      BEGIN
        new.search_index := to_tsvector('pg_catalog.english', replace_underscores(new.name) || ' ' || new.description);
        RETURN new;
      END
      $$ LANGUAGE plpgsql;
    """

    # Trigger updates.
    execute "UPDATE pools SET name=name;"
  end

  def self.down
    execute "DROP FUNCTION replace_underscores"
  end
end
