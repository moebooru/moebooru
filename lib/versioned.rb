module Versioned
  def get_versioned_classes
    [Pool, PoolPost, Post, Tag, Note]
  end
  module_function :get_versioned_classes

  def get_versioned_classes_by_name
    val = {}
    get_versioned_classes.each do |cls|
      val[cls.table_name] = cls
    end
    val
  end
  module_function :get_versioned_classes_by_name
end
