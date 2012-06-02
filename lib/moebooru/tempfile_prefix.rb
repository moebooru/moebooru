module Moebooru
  module TempfilePrefix
    attr_accessor :tempfile_prefix

    def tempfile_prefix
      if not @tempfile_prefix
        @tempfile_prefix = Rails.root.join('public/data').join("temp-#{Random.new.rand(2**32).to_s}")
      end
      return @tempfile_prefix
    end
  end
end
