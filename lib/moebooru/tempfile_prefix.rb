module Moebooru
  module TempfilePrefix
    attr_accessor :tempfile_prefix

    def tempfile_prefix
      @tempfile_prefix ||= Rails.root.join("public/data").join("temp-#{SecureRandom.random_number(2**32)}")
    end
  end
end
