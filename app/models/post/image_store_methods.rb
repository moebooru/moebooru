module Post::ImageStoreMethods
  def self.included(m)
    case CONFIG["image_store"]
    when :local_flat then m.__send__(:include, Post::ImageStore::LocalFlat)
    when :local_hierarchy then m.__send__(:include, Post::ImageStore::LocalHierarchy)
    when :remote_hierarchy then m.__send__(:include, Post::ImageStore::RemoteHierarchy)
    else m.__send__(:include, Post::ImageStore::Local2)
    end
  end

  private

  def url_encode(*args)
    ERB::Util.url_encode *args
  end
end
