class AddNaturalSortToPools < ActiveRecord::Migration[5.1]
  def self.up
    execute <<-EOS
      CREATE OR REPLACE FUNCTION nat_sort_pad(t text) RETURNS text IMMUTABLE AS $$
      DECLARE
        match text;
      BEGIN
        IF t ~ '[0-9]' THEN
          match := '0000000000' || t;
          match := SUBSTRING(match FROM '^0*([0-9]{10}[0-9]*)$');
          return match;
        END IF;
        return t;
      END;
      $$ LANGUAGE plpgsql;
    EOS

    execute <<-EOS
      CREATE OR REPLACE FUNCTION nat_sort(t text) RETURNS text IMMUTABLE AS $$
      BEGIN
        return array_to_string(array(select nat_sort_pad((regexp_matches(t, '([0-9]+|[^0-9]+)', 'g'))[1])), '');
      END;
      $$ LANGUAGE plpgsql;
    EOS

    execute "CREATE INDEX idx_pools__name_nat ON pools (nat_sort(name))"
  end

  def self.down
    execute "DROP INDEX idx_pools__name_nat"
    execute "DROP FUNCTION nat_sort_pad(t text)"
    execute "DROP FUNCTION nat_sort(t text)"
  end
end
