atom_feed :root_url => url_for(:controller => :post, :action => :index, :only_path => false) do |feed|
  feed.title CONFIG['app_name']
  feed.updated @posts[0].created_at if @posts.length > 0
  @posts.each do |post|
    post_url = url_for :controller => :post, :action => :show, :id => post.id, :only_path => false
    post_preview_url = URI.join root_url(:only_path => false), post.preview_url
    feed.entry post, :url => post_url, :updated => post.created_at do |entry|
      entry.link :href => post.source, :rel => 'related' unless post.source.blank?
      entry.link :href => post_preview_url, :rel => 'enclosure'
      entry.title '%s [%s]' % [post.cached_tags, "#{post.width}x#{post.height}"]
      entry.summary post.cached_tags
      entry.content render(:partial => 'post_atom', :formats => :html, :locals => { :post => post, :post_url => post_url }), :type => 'html'
      entry.author do |author|
        author.name post.author
        author.url url_for(:controller => :user, :action => :show, :id => post.user_id, :only_path => false)
      end
    end
  end
end
