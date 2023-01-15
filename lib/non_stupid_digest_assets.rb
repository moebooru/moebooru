# Taken from [1] with file existence check updated to work with ruby 3.2
# by renaming `File.exists?` to `File.exist?`.
#
# [1] https://github.com/alexspeller/non-stupid-digest-assets/blob/cb899cc4bad242c9da7c0ef61d4f9e431e020119/lib/non-stupid-digest-assets.rb
require "sprockets/manifest"

module NonStupidDigestAssets
  mattr_accessor :whitelist
  @@whitelist = []

  class << self
    def assets(assets)
      return assets if whitelist.empty?
      whitelisted_assets(assets)
    end

    private

    def whitelisted_assets(assets)
      assets.select do |logical_path, digest_path|
        whitelist.any? do |item|
          item === logical_path
        end
      end
    end
  end

  module CompileWithNonDigest
    def compile *args
      paths = super
      NonStupidDigestAssets.assets(assets).each do |(logical_path, digest_path)|
        full_digest_path = File.join dir, digest_path
        full_digest_gz_path = "#{full_digest_path}.gz"
        full_non_digest_path = File.join dir, logical_path
        full_non_digest_gz_path = "#{full_non_digest_path}.gz"

        if File.exist? full_digest_path
          logger.debug "Writing #{full_non_digest_path}"
          FileUtils.copy_file full_digest_path, full_non_digest_path, :preserve_attributes
        else
          logger.debug "Could not find: #{full_digest_path}"
        end
        if File.exist? full_digest_gz_path
          logger.debug "Writing #{full_non_digest_gz_path}"
          FileUtils.copy_file full_digest_gz_path, full_non_digest_gz_path, :preserve_attributes
        else
          logger.debug "Could not find: #{full_digest_gz_path}"
        end
      end
      paths
    end
  end
end
