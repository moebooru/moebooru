module InlineHelper
  def inline_image_tag(image, options = {}, tag_options = {})
    if options[:use_sample] and image.has_sample?
      url = image.sample_url
      tag_options[:width] = image.sample_width
      tag_options[:height] = image.sample_height
    else
      url = image.file_url
      tag_options[:width] = image.width
      tag_options[:height] = image.height
    end

    image_tag(url, tag_options)
  end
end
