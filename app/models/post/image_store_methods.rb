module PostImageStoreMethods
  def self.included(m)
    case CONFIG["image_store"]
    when :local_flat
      m.__send__(:include, PostImageStoreMethods::LocalFlat)
  
    when :local_flat_with_amazon_s3_backup
      m.__send__(:include, PostImageStoreMethods::LocalFlatWithAmazonS3Backup)

    when :local_hierarchy
      m.__send__(:include, PostImageStoreMethods::LocalHierarchy)

    when :remote_hierarchy
      m.__send__(:include, PostImageStoreMethods::RemoteHierarchy)

    when :amazon_s3
      m.__send__(:include, PostImageStoreMethods::AmazonS3)
    end
  end
end
