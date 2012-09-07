provide :title, 'Pools'
atom_feed :root_url => url_for(:controller => :pool, :action => :index, :only_path => false) do |feed|
  feed.title atom_title
  feed.updated @pools.first.created_at if @pools.length > 0
  @samples.each do |pool, post|
    sample = post
    pool_url = url_for :controller => :pool, :action => :show, :id => pool.id, :only_path => false, :format => nil
    pool_preview_url = URI.join root_url(:only_path => false), sample.preview_url
    feed.entry pool, :url => pool_url, :updated => pool.created_at do |entry|
      entry.link :href => pool_preview_url, :rel => 'enclosure'
      entry.title pool.pretty_name
      entry.summary pool.description unless pool.description.blank?
      entry.content render(:partial => 'pool_atom', :formats => :html, :locals => { :pool => pool, :sample => sample, :pool_url => pool_url }), :type => 'html'
    end
  end
end
