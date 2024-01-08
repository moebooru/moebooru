# frozen_string_literal: true

module Moebooru
  # Get image size and format. It'll return oriented image size if applicable.
  module ImageSizeExif
    def self.data(stream)
      parse MiniMagick::Image.read(stream)
    end

    def self.parse(image)
      ret = {
        colorspace: image["%[colorspace]"],
        height: image.height,
        width: image.width,
        type: image.type
      }

      ret[:height], ret[:width] = ret[:width], ret[:height] if %w[5 6 7 8].include? image.exif["Orientation"]

      ret
    rescue MiniMagick::Error
      {}
    end

    def self.path(file_path)
      parse MiniMagick::Image.new(file_path)
    end
  end
end
