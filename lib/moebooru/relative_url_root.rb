module Moebooru
  module RelativeUrlRoot
    def self.path
      ENV['RAILS_RELATIVE_URL_ROOT'] || '/'
    end
  end
end
