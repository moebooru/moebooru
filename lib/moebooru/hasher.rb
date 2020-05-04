# frozen_string_literal: true

require_relative './hasher/crc32'
require_relative './hasher/md5'

module Moebooru
  # File hashing helper
  module Hasher
    BLOCK_SIZE = 2**20

    HASHERS = {
      crc32: Crc32,
      md5: Md5
    }.freeze

    def self.compute(path, hashes)
      return {} if hashes.empty?

      hashers = hashes.map { |h| [h, HASHERS[h].new] }.to_h

      File.open(path, 'rb') do |fp|
        while (block = fp.read(BLOCK_SIZE))
          hashers.each_value { |h| h.append block }
        end
      end

      hashers.transform_values(&:hash)
    end

    def self.compute_one(path, hash)
      compute(path, [hash])[hash]
    end
  end
end
