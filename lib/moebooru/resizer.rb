module Moebooru
  module Resizer
    class ResizeError < Exception; end

    def resize(file_ext, read_path, write_path, output_size, output_quality)
      image = MiniMagick::Image.open(read_path)
      output_size[:width] ||= image[:width]
      output_size[:height] ||= image[:height]
      output_size[:crop_top] ||= 0
      output_size[:crop_bottom] ||= image[:height]
      output_size[:crop_left] ||= 0
      output_size[:crop_right] ||= image[:width]
      output_size[:crop_width] ||= output_size[:crop_right] - output_size[:crop_left]
      output_size[:crop_height] ||= output_size[:crop_bottom] - output_size[:crop_top]
      # The '!' is required to force the size, otherwise ImageMagick will try
      # to outsmart the previously calculated size which isn't exactly smart.
      # Example: 1253x1770 -> 212x300. In ImageMagick it becomes 212x299.
      write_size = "#{output_size[:width]}x#{output_size[:height]}!"
      write_crop = "#{output_size[:crop_width]}x#{output_size[:crop_height]}+#{output_size[:crop_left]}+#{output_size[:crop_top]}"
      write_format = write_path.split('.')[-1]
      if write_format =~ /\A(jpe?g|gif|png)\z/i
        write_format = write_format.downcase
      else
        format = file_ext
      end
      image.format write_format do |f|
        f.background CONFIG['bgcolor']
        f.flatten
        f.crop write_crop
        f.resize write_size
        f.repage.+
        if write_format =~ /\Ajpe?g\z/
          f.sampling_factor '2x2,1x1,1x1'
        end
        f.quality output_quality.to_s
      end
      image.write write_path
      rescue IOError
        raise
      rescue Exception => e
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

      if min_max then
        if max_size[:width] < max_size[:height] != size[:width] < size[:height] then
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
