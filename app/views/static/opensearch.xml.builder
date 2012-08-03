xml.instruct!
xml.OpenSearchDescription :xmlns => 'http://a9.com/-/spec/opensearch/1.1/' do
  xml.ShortName CONFIG['app_name']
  xml.Description "Search images in #{CONFIG['app_name']} image board."
  xml.Contact CONFIG['admin_contact']
  xml.AdultContent '1'
  xml.Url :type => Mime::HTML, :template => "#{url_for(:controller => :post, :action => :index, :only_path => false)}?tags={searchTerms}"
end
