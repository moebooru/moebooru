class FixNatSortFunction < ActiveRecord::Migration[6.0]
  def up
    execute <<-EOS
      CREATE or replace FUNCTION public.nat_sort(t text) RETURNS text
      LANGUAGE plpgsql IMMUTABLE
      AS $$
      BEGIN
        return array_to_string(array(select public.nat_sort_pad((regexp_matches(t, '([0-9]+|[^0-9]+)', 'g'))[1])), '');
      END;
      $$;
    EOS
  end

  def down
    # nothing because this only fixes broken function
  end
end
