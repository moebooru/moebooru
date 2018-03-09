class PostFrames < ActiveRecord::Base
  include Moebooru::TempfilePrefix
  belongs_to :post

  # Parse a frame specifier.
  def self.parse_frames(data_string, post_id = nil)
    # Parse a frames string.  This is a semicolon-separated string of frames.  Each frame is
    # of the format:
    #
    # AxB,CxD
    #
    # eg.
    # 100x100,200x200;300x300,400x400
    #
    # AxB: top-left corner of the source image
    # CxD: size of the image inside the source image
    frames = []
    data_string.split(";").each do |frame_data|
      split_data = frame_data.split(",").map { |f| f.split("x").map(&:to_i) }
      p = {
        :source_left => split_data[0][0],
        :source_top => split_data[0][1],
        :source_width => split_data[1][0],
        :source_height => split_data[1][1]
      }
      p[:post_id] = post_id if post_id
      frames << p
    end
    frames
  end

  # Generate a frame specifier, from an array of either a PostFrames or parse_frames output.
  def self.format_frames(frames)
    result = []
    frames.each do |frame|
      result << "#{frame[:source_left]}x#{frame[:source_top]},#{frame[:source_width]}x#{frame[:source_height]}"
    end
    result.join(";")
  end

  def self.frame_image_dimensions(frame)
    size = { :width => frame[:source_width], :height => frame[:source_height] }

    unless CONFIG["sample_width"].nil?
      size = Moebooru::Resizer.reduce_to(size, { :width => CONFIG["sample_width"], :height => CONFIG["sample_height"] }, CONFIG["sample_ratio"])
    end
    size = Moebooru::Resizer.reduce_to(size, { :width => CONFIG["sample_max"], :height => CONFIG["sample_min"] }, 1, false, true)

    size
  end

  def self.frame_preview_dimensions(frame)
    Moebooru::Resizer.reduce_to({ :width => frame[:source_width], :height => frame[:source_height] },
                                :width => 300, :height => 300)
  end

  # Clamp frames to the size of the actual post, and remove any empty frames.
  def self.sanitize_frames(frames, post)
    frames.each do |frame|
      frame[:source_left] = [frame[:source_left], post.width].min
      frame[:source_top] = [frame[:source_top], post.height].min
      frame[:source_width] = [frame[:source_width], post.width - frame[:source_left]].min
      frame[:source_height] = [frame[:source_height], post.height - frame[:source_top]].min
    end
    frames.delete_if { |frame| frame[:source_width] == 0 || frame[:source_height] == 0 }
  end

  # Look for post frames that need work, and do some processing.
  def self.process_frames(update_status = nil)
    # Find a post with out-of-date frames.  This SQL is designed to use the
    # post_frames_out_of_date index.
    post = Post.find_by("frames <> frames_pending AND (frames <> '' OR frames_pending <> '')")
    unless post.nil?
      if update_status
        update_status.call("Creating frames for post #{post.id}")
      end
      return PostFrames.process_post(post)
    end
  end

  def self.find_frame(frame_desc)
    conds = {
      :post_id => frame_desc[:post_id],
      :source_left => frame_desc[:source_left],
      :source_top => frame_desc[:source_top],
      :source_width => frame_desc[:source_width],
      :source_height => frame_desc[:source_height]
    }
    PostFrames.find_by(conds)
  end

  def self.process_post(post)
    logger.info("Processing frames for post #{post.id}")

    # Create rows for any frames that don't exist yet, set is_target true on all frames in post.frames,
    # and set it false for the rest.
    frames = PostFrames.parse_frames(post.frames_pending, post.id)

    where(:post_id => post.id).update_all(:is_target => false)
    frames.each_index do |idx|
      frame_desc = frames[idx]
      frame = PostFrames.find_frame(frame_desc)
      if frame.nil?
        logger.info("Create frame row: #{frame_desc}")
        frame = PostFrames.create(frame_desc)
      end
      frame.is_target = true
      frame.save!
    end

    # We now have PostFrames rows for this post, and the frames we want to exist are set is_target.
    # From here on, we'll only do a single step of the process at a time and return.  Find some
    # work to do.
    #
    # Try to find a post that needs to be created.
    frame = PostFrames.find_by(:post_id => post.id, :is_target => true, :is_created => false)
    if frame
      frame.create_file
      return true
    end

    # All frames are created.  Finalize the frames, activating the target ones and deactivating the
    # old non-target ones.
    logger.info("Finished creating frames for post #{post.id}; finalizing")
    where(:post_id => post.id).update_all("is_active = is_target")

    # Set frames_warehoused to true only if all of the new target frames are already warehoused.
    frames_warehoused = !PostFrames.exists?(["post_id = ? AND is_target AND NOT is_warehoused", post.id])

    # Update the post's frames to reflect the newly activated frames.
    post.update_attributes(:frames => post.frames_pending, :frames_warehoused => frames_warehoused)

    # Return false; there's nothing more for us to do with this post.
    false
  end

  # Warehouse frames.  Only frames which are created and finalized will be warehoused.
  def self.warehouse_frames(update_status = nil)
    # Find a post with frames that need warehousing.
    post = Post.find_by("frames = frames_pending AND frames <> '' AND NOT frames_warehoused")
    return false if post.nil?

    # Try to find a frame that needs to be warehoused.
    frame = PostFrames.find_by(:post_id => post.id, :is_active => true, :is_warehoused => false)
    if frame
      if update_status
        update_status.call("Warehousing frames for post #{frame.post_id}")
      end
      frame.warehouse_frame
      return true
    end

    # All frames are warehoused.
    post.update_attributes(:frames_warehoused => true)
    true
  end

  # Posts that are neither active nor target are no longer needed.  Incrementally them up and delete them.
  def self.purge_frames(update_status = nil)
    if update_status
      update_status.call("Cleaning up old post frames")
    end

    # Find a file that needs to be unwarehoused.
    frame = PostFrames.find_by(:is_target => false, :is_active => false, :is_warehoused => true)
    unless frame.nil?
      if update_status
        update_status.call("Unwarehousing old frames for post #{frame.post_id}")
      end

      # XXX
      logger.info("Unwarehousing #{frame.id}")
      frame.update_attributes(:is_warehoused => false)
      return
    end

    # Find a file that needs to be deleted.  Only do this after unwarehousing the image, so we don't
    # end up in a confusing state where a file is on a mirror and not the master.
    frame = PostFrames.find_by(:is_active => false, :is_target => false, :is_created => true, :is_warehoused => false)
    unless frame.nil?
      logger.info("Deleting #{frame.id}")
      FileUtils.rm_f(frame.file_path)
      frame.update_attributes(:is_created => false)
      return
    end

    # Delete any records that are completely cleaned up.
    where(:is_target => false, :is_active => false, :is_created => false, :is_warehoused => false).delete_all
  end

  def create_file
    return unless is_target
    return if is_created

    logger.info("Create post frame: post ##{post_id}, frame #{id}")
    image_size = PostFrames.frame_image_dimensions(self)
    image_size[:crop_top] = source_top.to_f
    image_size[:crop_bottom] = source_top + source_height
    image_size[:crop_left] = source_left.to_f
    image_size[:crop_right] = source_left + source_width

    image_tempfile_path = "#{tempfile_prefix}.frame.jpg"
    preview_tempfile_path = "#{tempfile_prefix}.frame-preview.jpg"

    preview_size = PostFrames.frame_preview_dimensions(self)

    begin
      FileUtils.mkdir_p File.dirname(post.file_path)
      FileUtils.mkdir_p File.dirname(post.preview_path)
      Moebooru::Resizer.resize(post.file_ext, post.file_path, image_tempfile_path, image_size, 95)

      # Save time by creating the thumbnail directly from the image we just created, instead
      # of from the original, so we don't have to re-decode whole PNGs.
      Moebooru::Resizer.resize("jpg", image_tempfile_path, preview_tempfile_path, preview_size, 85)
    rescue => e
      FileUtils.rm_f(image_tempfile_path)
      FileUtils.rm_f(preview_tempfile_path)
      raise e
    end

    FileUtils.mv(image_tempfile_path, file_path)
    FileUtils.chmod(0775, file_path)

    FileUtils.mv(preview_tempfile_path, preview_path)
    FileUtils.chmod(0775, preview_path)

    # Save the dimensions we computed, and mark the file created.
    update_attributes(:is_created => true)
  end

  def warehouse_frame
    return if is_warehoused
    return unless is_created

    logger.info("Warehousing frame #{id}...")
    Mirrors.copy_file_to_mirrors(file_path)
    Mirrors.copy_file_to_mirrors(preview_path)

    # Mark the frame warehoused.
    update_attributes(:is_warehoused => true)
  end

  def self.filename(frame)
    "#{frame[:post_id]}-#{frame[:source_left]}x#{frame[:source_top]}-#{frame[:source_width]}x#{frame[:source_height]}.jpg"
  end

  def file_path
    "#{Rails.root}/public/data/frame/#{PostFrames.filename(self)}"
  end

  def preview_path
    "#{Rails.root}/public/data/frame-preview/#{PostFrames.filename(self)}"
  end
end
