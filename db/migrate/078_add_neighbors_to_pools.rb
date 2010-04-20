class PoolPost < ActiveRecord::Base
  set_table_name "pools_posts"
  belongs_to :pool
end

class Pool < ActiveRecord::Base
  has_many :pool_posts, :class_name => "PoolPost", :order => "sequence"
end

class AddNeighborsToPools < ActiveRecord::Migration
  def self.up
    add_column :pools_posts, :next_post_id, :integer
    add_column :pools_posts, :prev_post_id, :integer
    add_foreign_key :pools_posts, :next_post_id, :posts, :id, :on_delete => :set_null
    add_foreign_key :pools_posts, :prev_post_id, :posts, :id, :on_delete => :set_null
    
    PoolPost.reset_column_information
    
    Pool.find(:all).each do |pool|
      pp = pool.pool_posts

      pp.each_index do |i|
        pp[i].next_post_id = pp[i + 1].post_id unless i == pp.size - 1
        pp[i].prev_post_id = pp[i - 1].post_id unless i == 0
        pp[i].save
      end
    end
  end

  def self.down
    remove_column :pools_posts, :next_post_id
    remove_column :pools_posts, :prev_post_id
  end
end
