require 'danbooru_image_resizer/danbooru_image_resizer.so'

module Danbooru
  class ResizeError < Exception; end

  # If output_quality is an integer, it specifies the JPEG output quality to use.
  #
  # If it's a hash, it's of this form:
  # { :min => 90, :max => 100, :filesize => 1048576 }
  #
  # This will search for the highest quality compression under :filesize between 90 and 100.
  # This allows cleanly filtered images to receive a high compression ratio, but allows lowering
  # the compression on noisy images.
  def resize(file_ext, read_path, write_path, output_size, output_quality)
    if output_quality.class == Fixnum
      output_quality = { :min => output_quality, :max => output_quality, :filesize => 1024*1024*1024 }
    end

    # A binary search is a poor fit here: we'd always have to do at least two compressions
    # to find out whether the conversion we've done is the maximum fit, and most images will
    # generally fit with maximum-quality compression anyway.  Just search linearly from :max
    # down.
    quality = output_quality[:max]
    begin
      while true
        # If :crop is set, crop between [crop_top,crop_bottom) and [crop_left,crop_right)
        # before resizing.
        Danbooru.resize_image(file_ext, read_path, write_path, output_size[:width], output_size[:height],
                              output_size[:crop_top] || 0, output_size[:crop_bottom] || 0, output_size[:crop_left] || 0, output_size[:crop_right] || 0,
                              quality)

        # If the file is small enough, or if we're at the lowest allowed quality setting
        # already, finish.
        return if !output_quality[:filesize].nil? && File.size(write_path) <= output_quality[:filesize]
        return if quality <= output_quality[:min]
        quality -= 1
      end
    rescue IOError
      raise
    rescue Exception => e
      raise ResizeError, e.to_s
    end
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
