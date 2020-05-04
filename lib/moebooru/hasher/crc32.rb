# frozen_string_literal: true

require 'zlib'

module Moebooru
  module Hasher
    # CRC32 hasher, returns hash in integer form
    class Crc32
      def initialize
        @crc32 = 0
      end

      def append(block)
        @crc32 = Zlib.crc32(block, @crc32)
      end

      def hash
        @crc32
      end
    end
  end
end
