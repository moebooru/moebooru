class ExternalPost
  # These mimic the equivalent attributes in Post directly.
  attr_accessor :md5, :url, :preview_url, :service, :width, :height, :tags, :rating, :id

  class << self
    def get_service_icon(service)
      if service == CONFIG["local_image_service"] then
	"/favicon.ico"
      elsif service == "gelbooru.com" then # hack
	"/favicon-" + service + ".png"
      else
	"/favicon-" + service + ".ico"
      end
    end
  end

  def service_icon
    ExternalPost.get_service_icon(service)
  end
  def ext
    true
  end
  def cached_tags
    tags
  end

  def to_xml(options = {})
    {:md5 => md5, :url => url, :preview_url => preview_url, :service => service}.to_xml(options.merge(:root => "external-post"))
  end

  def preview_dimensions
    dim = Danbooru.reduce_to({:width => width, :height => height}, {:width => 150, :height => 150})
    return [dim[:width], dim[:height]]
  end

  def use_jpeg?(user) false end
  def has_jpeg? false end
end
