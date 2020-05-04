# frozen_string_literal: true

require 'digest'

module Moebooru
  module Hasher
    # MD5 hasher, returns hash in hex form
    class Md5
      def initialize
        @md5 = Digest::MD5.new
      end

      def append(block)
        @md5 << block
      end

      def hash
        @md5.hexdigest
      end
    end
  end
end
