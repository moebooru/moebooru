# Set the host name for URL creation
SitemapGenerator::Sitemap.default_host = "https://yande.re"
SitemapGenerator::Sitemap.create_index = true
SitemapGenerator::Sitemap.namer = SitemapGenerator::SimpleNamer.new(:sitemap, :zero => "_index")

SitemapGenerator::Sitemap.create do
  # Put links creation logic here.
  #
  # The root path '/' and sitemap index file are added automatically for you.
  # Links are added to the Sitemap in the order they are specified.
  #
  # Usage: add(path, options={})
  #        (default options are used if you don't specify)
  #
  # Defaults: :priority => 0.5, :changefreq => 'weekly',
  #           :lastmod => Time.now, :host => default_host
  #
  # Examples:
  #
  # Add '/articles'
  #
  #   add articles_path, :priority => 0.7, :changefreq => 'daily'
  #
  # Add all articles:
  #
  #   Article.find_each do |article|
  #     add article_path(article), :lastmod => article.updated_at
  #   end
  Post.available.pluck(:id).each do |post_id|
    add "/post/show/#{post_id}", :changefreq => "daily"
  end

  Tag.pluck(:name).each do |tag_name|
    add url_for(:controller => :post, :action => :index, :tags => tag_name, :only_path => true), :changefreq => "daily"
  end
end
