module Post::FrameMethods
  def self.included(m)
    m.versioned :frames_pending, :default => "", :allow_reverting_to_default => true
  end

  def frames_pending_string=(frames)
#    if r == nil && !new_record?
#      return
#    end

    # This cleans up the frames string, and fills in the final dimensions spec.
    parsed = PostFrames.parse_frames(frames, id)
    PostFrames.sanitize_frames(parsed, self)
    new_frames = PostFrames.format_frames(parsed)

    return if frames_pending == new_frames
#    self.old_rating = self.frames
    write_attribute(:frames_pending, new_frames)
    touch_change_seq!
  end

  def frames_api_data(data)
    frames = PostFrames.parse_frames(data, id)

    frames.each_with_index do |frame, i|
      frame[:post_id] = id

      size = PostFrames.frame_image_dimensions(frame)
      frame[:width] = size[:width]
      frame[:height] = size[:height]

      size = PostFrames.frame_preview_dimensions(frame)
      frame[:preview_width] = size[:width]
      frame[:preview_height] = size[:height]

      filename = PostFrames.filename(frame)
      server = Mirrors.select_image_server(frames_warehoused, created_at.to_i + i)
      frame[:url] = server + "/data/frame/#{filename}"

      thumb_server = Mirrors.select_image_server(frames_warehoused, created_at.to_i + i, :use_aliases => true)
      frame[:preview_url] = thumb_server + "/data/frame-preview/#{filename}"
    end

    frames
  end
end
