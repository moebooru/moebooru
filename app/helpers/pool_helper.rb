module PoolHelper
  def pool_list(post)
    html = ""
    pools = Pool
      .joins("JOIN pools_posts ON pools_posts.pool_id = pools.id")
      .where(pools_posts: { post_id: post.id })
      .order(:name).select(:name, :id)

    if pools.empty?
      html << "none"
    else
      html << pools.map { |p| link_to(h(p.pretty_name), controller: "pool", action: "show", id: p.id) }.join(", ")
    end

    html
  end

  def link_to_pool_zip(text, pool, zip_params, options = {})
    text = "%s%s (%s)" % [ text,
                          options[:has_jpeg] ? " PNGs" : "",
                          number_to_human_size(pool.get_zip_size(zip_params).to_i)
                         ]
    options = { action: "zip", id: pool.id }
    options[:jpeg] = 1 if zip_params[:jpeg]
    link_to text, options, level: :member
  end
end
