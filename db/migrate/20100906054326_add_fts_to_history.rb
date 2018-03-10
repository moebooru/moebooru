class AddFtsToHistory < ActiveRecord::Migration[5.1]
  def self.up
    execute "SET statement_timeout = 0"
    execute "SET search_path = public"

    execute "ALTER TABLE history_changes ADD COLUMN value_index tsvector"

    # Is there seriously no string join function in Postgres, even though it has three
    # different functions for split?
    execute """
    CREATE OR REPLACE FUNCTION join_string(words varchar[], delimitor varchar) RETURNS varchar AS $$
    DECLARE
      result varchar := '';
      first boolean := true;
    BEGIN
      FOR i IN coalesce(array_lower(words, 1), 0) .. coalesce(array_upper(words, 1), 0) LOOP
        IF NOT first THEN
          result := result || delimitor;
        ELSE
          first := false;
        END IF;

        result := result || words[i];
      END LOOP;
      RETURN result;
    END
    $$ LANGUAGE plpgsql;
    """

    execute """
    CREATE OR REPLACE FUNCTION get_new_tags(old_array varchar[], new_array varchar[]) RETURNS varchar[] AS $$
    DECLARE
      changed_tags varchar[];
    BEGIN
      FOR i IN array_lower(new_array, 1) .. array_upper(new_array, 1) LOOP
        IF NOT new_array[i] = ANY (old_array) THEN
          changed_tags := array_append(changed_tags, new_array[i]);
        END IF;
      END LOOP;

      RETURN changed_tags;
    END
    $$ LANGUAGE plpgsql;
    """

    # For most value fields, just index it directly.  For cached_tags, index the changes compared
    # to the previous value.
    execute """
    CREATE OR REPLACE FUNCTION history_changes_index_trigger() RETURNS trigger AS $$
    DECLARE
      old_tags varchar;
      old_tags_array varchar[];
      new_tags_array varchar[];
      changed_tags_array varchar[];
      indexed_value varchar;
    BEGIN
      IF (new.table_name, new.field) IN (('posts', 'cached_tags')) THEN
        old_tags := prev.value FROM history_changes prev WHERE (prev.id = new.previous_id) LIMIT 1;
        old_tags_array := regexp_split_to_array(COALESCE(old_tags, ''), ' ');
        new_tags_array := regexp_split_to_array(COALESCE(new.value, ''), ' ');

        changed_tags_array := get_new_tags(old_tags_array, new_tags_array);
        changed_tags_array := array_cat(changed_tags_array, get_new_tags(new_tags_array, old_tags_array));
        indexed_value := join_string(changed_tags_array, ' ');
      ELSEIF (new.table_name, new.field) IN (('pools', 'name')) THEN
        indexed_value := translate(new.value, '_', ' ');
      ELSEIF (new.table_name, new.field) IN (('posts', 'cached_tags'), ('posts', 'source'), ('pools', 'description')) THEN
        indexed_value := new.value;
      ELSE
        RETURN new;
      END IF;

      new.value_index := to_tsvector('public.danbooru', indexed_value);

      RETURN new;
    END
    $$ LANGUAGE plpgsql;
    """

    execute """
    CREATE TRIGGER trg_history_changes_value_index_update BEFORE INSERT OR UPDATE ON history_changes
    FOR EACH ROW EXECUTE PROCEDURE history_changes_index_trigger();
    """

    # Trigger a value_index update for all rows.
    execute "UPDATE history_changes SET value = value"

    # Create the index after updating.
    execute "CREATE INDEX index_history_changes_on_value_index ON history_changes USING gin(value_index)"
  end

  def self.down
    execute "ALTER TABLE history_changes DROP COLUMN value_index"
  end
end
