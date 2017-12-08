cache [@posts.map(&:id), page_number], :expires => 1.hour do
  xml.instruct!
  xml.rss :version => '2.0', :'xmlns:media' => 'http://search.yahoo.com/mrss/', :'xmlns:atom' => 'http://www.w3.org/2005/Atom' do
    xml.channel do
      xml.title "#{CONFIG['app_name']}/#{params[:tags]}"
      xml.link root_url(:only_path => false)
      xml.tag! :'atom:link', :rel => 'self', :href => url_for(:only_path => false)
      xml.description "#{CONFIG['app_name']} PicLens RSS Feed"
      unless @posts.previous_page.nil?
        xml.tag! :'atom:link', :rel => 'previous', :href => url_for(:controller => '/post', :action => :piclens, :page => @posts.previous_page, :tags => params[:tags], :only_path => false)
      end
      unless @posts.next_page.nil?
        xml.tag! :'atom:link', :rel => 'next', :href => url_for(:controller => '/post', :action => :piclens, :page => @posts.next_page, :tags => params[:tags], :only_path => false)
      end
      @posts.each do |post|
        xml.item do
          xml.title post.cached_tags
          xml.link url_for(:controller => '/post', :action => :show, :id => post.id, :only_path => false)
          xml.guid url_for(:controller => '/post', :action => :show, :id => post.id, :only_path => false)
          xml.description do
            xml.cdata! tag(:img, :src => post.preview_url, :alt => post.cached_tags)
          end
          xml.tag! :'media:thumbnail', :url => post.preview_url
          content_url = CONFIG['image_samples'] ? post.sample_url : post.file_url
          xml.tag! :'media:content', :url => content_url, :type => MiniMime.lookup_by_filename(content_url)&.content_type
        end
      end
    end
  end
end
