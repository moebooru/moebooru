require "mini_magick"

module Moebooru
  module Resizer
    class ResizeError < Exception; end

    BGCOLOR = (CONFIG["bgcolor"] if defined? CONFIG) || "white"
    ICC_DIR = File.expand_path "../resizer/icc", __FILE__

    # Meaning of sRGB and RGB flipped at 6.7.5.
    # Reference: http://www.imagemagick.org/discourse-server/viewtopic.php?f=2&t=20501
    TARGET_COLORSPACE = Gem::Version.create(MiniMagick.cli_version[/\d+\.\d+\.\d+/]) >= Gem::Version.create("6.7.5") ?
                        "sRGB" : "RGB"

    def resize(file_ext, input_path, output_path, output_size, output_quality)
      input_image = MiniMagick::Image.new(input_path)

      colorspace = input_image["%[colorspace]"]

      if output_size[:width] && output_size[:height].nil?
        output_size[:height] = input_image[:height] * output_size[:width] / input_image[:width]
      elsif output_size[:height] && output_size[:width].nil?
        output_size[:width] = input_image[:width] * output_size[:height] / input_image[:height]
      else
        output_size[:width] ||= input_image[:width]
        output_size[:height] ||= input_image[:height]
      end

      output_size[:crop_top] ||= 0
      output_size[:crop_bottom] ||= input_image[:height]
      output_size[:crop_left] ||= 0
      output_size[:crop_right] ||= input_image[:width]
      output_size[:crop_width] ||= output_size[:crop_right] - output_size[:crop_left]
      output_size[:crop_height] ||= output_size[:crop_bottom] - output_size[:crop_top]

      # The '!' is required to force the size, otherwise ImageMagick will try
      # to outsmart the previously calculated size which isn't exactly smart.
      # Example: 1253x1770 -> 212x300. In ImageMagick it becomes 212x299.
      write_size = "#{output_size[:width]}x#{output_size[:height]}!"

      write_crop = "#{output_size[:crop_width]}x#{output_size[:crop_height]}+#{output_size[:crop_left]}+#{output_size[:crop_top]}"

      write_format = output_path.split(".")[-1]
      if write_format =~ /\A(jpe?g|gif|png)\z/i
        write_format = write_format.downcase
      else
        write_format = file_ext
      end

      MiniMagick::Tool::Convert.new do |convert|
        convert << input_path
        convert.background BGCOLOR
        convert.flatten
        convert.crop write_crop
        convert.resize write_size
        convert.repage.+

        if write_format =~ /\Ajpe?g\z/
          convert.sampling_factor "2x2,1x1,1x1"
        end

        # Explicitly convert CMYK images
        if colorspace == "CMYK"
          convert.profile "#{ICC_DIR}/ISOcoated_v2_bas.ICC"
          convert.profile "#{ICC_DIR}/sRGB.icc"
        end

        # Any other colorspaces suck for storing images.
        # Since we're just resizing stuff here, actual colorspace shouldn't
        # matter much.
        # Except if it's grayscale. Just accept it as is.
        convert.colorspace TARGET_COLORSPACE if colorspace != "Gray"
        convert.quality output_quality.to_s

        convert << output_path
      end
    rescue IOError
      raise
    rescue => e
      raise ResizeError, e.to_s
    end

    # If allow_enlarge is true, always scale to fit, even if the source area is
    # smaller than max_size.
    #
    # If min_max is true, max_size[:width] and max_size[:height] are treated as bounding
    # the greater and lesser dimensions of the image.  For example, if max_size is 1500x1000,
    # then a landscape image will be scaled to 1500x1000, and a portrait image will be
    # 1000x1500.
    # the maximum scaling to 1000x1500.
    def reduce_to(size, max_size, ratio = 1, allow_enlarge = false, min_max = false)
      ret = size.dup

      if min_max
        if max_size[:width] < max_size[:height] != size[:width] < size[:height]
          max_size[:width], max_size[:height] = max_size[:height], max_size[:width]
        end
      end

      if allow_enlarge
        if ret[:width] < max_size[:width]
          scale = max_size[:width].to_f / ret[:width].to_f
          ret[:width] = ret[:width] * scale
          ret[:height] = ret[:height] * scale
        end

        if max_size[:height] && (ret[:height] < ratio * max_size[:height])
          scale = max_size[:height].to_f / ret[:height].to_f
          ret[:width] = ret[:width] * scale
          ret[:height] = ret[:height] * scale
        end
      end

      if ret[:width] > ratio * max_size[:width]
        scale = max_size[:width].to_f / ret[:width].to_f
        ret[:width] = ret[:width] * scale
        ret[:height] = ret[:height] * scale
      end

      if max_size[:height] && (ret[:height] > ratio * max_size[:height])
        scale = max_size[:height].to_f / ret[:height].to_f
        ret[:width] = ret[:width] * scale
        ret[:height] = ret[:height] * scale
      end

      ret[:width] = ret[:width].round
      ret[:height] = ret[:height].round
      ret
    end

    module_function :resize
    module_function :reduce_to
  end
end
