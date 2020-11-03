class AddPostWarehouseIndex < ActiveRecord::Migration[6.0]
  def change
    add_index :posts, :id,
      name: 'post_frames_for_warehouse',
      where: "frames = frames_pending AND frames <> '' AND NOT frames_warehoused"
  end
end
