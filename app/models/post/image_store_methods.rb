module Post::ImageStoreMethods
  def self.included(m)
    case CONFIG["image_store"]
    when :local_flat
      m.__send__(:include, Post::ImageStore::LocalFlat)

    when :local_flat_with_amazon_s3_backup
      m.__send__(:include, Post::ImageStore::LocalFlatWithAmazonS3Backup)

    when :local_hierarchy
      m.__send__(:include, Post::ImageStore::LocalHierarchy)

    when :remote_hierarchy
      m.__send__(:include, Post::ImageStore::RemoteHierarchy)

    when :amazon_s3
      m.__send__(:include, Post::ImageStore::AmazonS3)
    end
  end

  private

  def url_encode(*args)
    ERB::Util.url_encode *args
  end
end
