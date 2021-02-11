class DropExtraSequence < ActiveRecord::Migration[6.1]
  def up
    execute 'DROP SEQUENCE IF EXISTS posts_id_seq2'
  end

  def down
    # nothing to do here
  end
end
