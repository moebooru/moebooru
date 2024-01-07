module Moebooru
  module TempfilePrefix
    def tempfile_prefix
      @tempfile_prefix ||= Rails.root.join("tmp/work/temp-#{rand(2**32)}")
    end
  end
end
