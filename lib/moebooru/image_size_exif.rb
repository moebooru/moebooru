# frozen_string_literal: true

module Moebooru
  # Get image size and format. It'll return oriented image size if applicable.
  module ImageSizeExif
    def self.path(file_path)
      image = MiniMagick::Image.new(file_path)
      ret = {
        colorspace: image['%[colorspace]'],
        height: image.height,
        width: image.width,
        type: image.type
      }

      ret[:height], ret[:width] = ret[:width], ret[:height] if %w[5 6 7 8].include? image.exif['Orientation']

      ret
    rescue MiniMagick::Error
      {}
    end
  end
end
