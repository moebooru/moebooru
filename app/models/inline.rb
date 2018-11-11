class Inline < ApplicationRecord
  belongs_to :user
  has_many :inline_images, -> { order :sequence }, :dependent => :destroy

  # Sequence numbers must start at 1 and increase monotonically, to keep the UI simple.
  # If we've been given sequences with gaps or duplicates, sanitize them.
  def renumber_sequences
    first = 1
    for image in inline_images do
      image.sequence = first
      image.save!
      first += 1
    end
  end

  def pretty_name
    "x"
  end

  def crop(params)
    if params[:top].to_f < 0 || params[:top].to_f > 1 ||
        params[:bottom].to_f < 0 || params[:bottom].to_f > 1 ||
        params[:left].to_f < 0 || params[:left].to_f > 1 ||
        params[:right].to_f < 0 || params[:right].to_f > 1 ||
        params[:top] >= params[:bottom] ||
        params[:left] >= params[:right]

      errors.add(:parameter, "error")
      return false
    end

    def reduce_and_crop(image_width, image_height, params)
      cropped_image_width = image_width * (params[:right].to_f - params[:left].to_f)
      cropped_image_height = image_height * (params[:bottom].to_f - params[:top].to_f)

      size = {}
      size[:width] = cropped_image_width
      size[:height] = cropped_image_height
      size[:crop_top] = image_height * params[:top].to_f
      size[:crop_bottom] = image_height * params[:bottom].to_f
      size[:crop_left] = image_width * params[:left].to_f
      size[:crop_right] = image_width * params[:right].to_f
      size
    end

    images = inline_images
    for image in images do
      # Create a new image with the same properties, crop this image into the new one,
      # and delete the old one.
      new_image = InlineImage.new(:description => image.description, :sequence => image.sequence, :inline_id => id, :file_ext => "jpg")
      size = reduce_and_crop(image.width, image.height, params)

      begin
        # Create one crop for the image, and InlineImage will create the sample and preview from that.
        Moebooru::Resizer.resize(image.file_ext, image.file_path, new_image.tempfile_image_path, size, 95)
        FileUtils.chmod(0775, new_image.tempfile_image_path)
      rescue => x
        FileUtils.rm_f(new_image.tempfile_image_path)

        errors.add "crop", "couldn't be generated (#{x})"
        return false
      end

      new_image.got_file
      new_image.save!
      image.destroy
    end
  end

  def api_attributes
    {
      :id => id,
      :description => description,
      :user_id => user_id,
      :images => inline_images
    }
  end

  def as_json(*params)
    api_attributes.as_json(*params)
  end
end
