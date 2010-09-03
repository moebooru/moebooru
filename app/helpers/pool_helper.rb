module PoolHelper
  def pool_list(post)
    html = ""
    pools = Pool.find(:all, :joins => "JOIN pools_posts ON pools_posts.pool_id = pools.id", :conditions => "pools_posts.post_id = #{post.id}", :order => "pools.name", :select => "pools.name, pools.id")
    
    if pools.empty?
      html << "none"
    else
      html << pools.map {|p| link_to(h(p.pretty_name), :controller => "pool", :action => "show", :id => p.id)}.join(", ")
    end
    
    return html
  end

  def link_to_pool_zip(text, pool, zip_params, options={})
    text = "%s%s (%s)" % [text,
      options[:has_jpeg]? " PNGs":"",
      number_to_human_size(pool.get_zip_size(zip_params)),
    ]
    options = { :action => "zip", :id => pool.id, :filename => pool.get_zip_filename(zip_params) }
    options[:jpeg] = 1 if zip_params[:jpeg]
    link_to text, options, :level => :member
  end
end
