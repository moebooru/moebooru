class UpdateHistoriesTrigger < ActiveRecord::Migration[5.1]
  def up
    execute <<-SQL.strip_heredoc
      CREATE OR REPLACE FUNCTION history_changes_index_trigger() RETURNS trigger
          LANGUAGE plpgsql
          AS $$
          DECLARE
            old_tags varchar;
            old_tags_array varchar[];
            new_tags_array varchar[];
            changed_tags_array varchar[];
            indexed_value varchar;
          BEGIN
            IF (new.table_name, new.column_name) IN (('posts', 'cached_tags')) THEN
              old_tags := prev.value FROM history_changes prev WHERE (prev.id = new.previous_id) LIMIT 1;
              old_tags_array := regexp_split_to_array(COALESCE(old_tags, ''), ' ');
              new_tags_array := regexp_split_to_array(COALESCE(new.value, ''), ' ');

              changed_tags_array := get_new_tags(old_tags_array, new_tags_array);
              changed_tags_array := array_cat(changed_tags_array, get_new_tags(new_tags_array, old_tags_array));
              indexed_value := join_string(changed_tags_array, ' ');
            ELSEIF (new.table_name, new.column_name) IN (('pools', 'name')) THEN
              indexed_value := translate(new.value, '_', ' ');
            ELSEIF (new.table_name, new.column_name) IN (('posts', 'cached_tags'), ('posts', 'source'), ('pools', 'description'), ('notes', 'body')) THEN
              indexed_value := new.value;
            ELSE
              RETURN new;
            END IF;

            new.value_index := to_tsvector('public.danbooru', indexed_value);

            RETURN new;
          END
          $$;
    SQL
  end

  def down
    execute <<-SQL.strip_heredoc
      CREATE OR REPLACE FUNCTION history_changes_index_trigger() RETURNS trigger
          LANGUAGE plpgsql
          AS $$
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
            ELSEIF (new.table_name, new.field) IN (('posts', 'cached_tags'), ('posts', 'source'), ('pools', 'description'), ('notes', 'body')) THEN
              indexed_value := new.value;
            ELSE
              RETURN new;
            END IF;

            new.value_index := to_tsvector('public.danbooru', indexed_value);

            RETURN new;
          END
          $$;
    SQL
  end
end
