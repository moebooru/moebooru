class AddRatioToPosts < ActiveRecord::Migration[7.2]
  def change
    add_column :posts, :ratio, 'numeric GENERATED ALWAYS AS (ROUND(width::numeric / GREATEST(1, height), 3)) STORED'
  end
end
