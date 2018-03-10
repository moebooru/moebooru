class FixSequenceName < ActiveRecord::Migration[5.1]
  def up
    execute "ALTER SEQUENCE favorite_tags_id_seq RENAME TO tag_subscriptions_id_seq"
  end

  def down
    execute "ALTER SEQUENCE tag_subscriptions_id_seq RENAME TO favorite_tags_id_seq"
  end
end
