module PostFrameMethods
  def self.included(m)
    m.versioned :frames_pending, :default => "", :allow_reverting_to_default => true
  end

  def frames_pending_string=(frames)
#    if r == nil && !new_record?
#      return
#    end

    # This cleans up the frames string, and fills in the final dimensions spec.
    parsed = PostFrames.parse_frames(frames, self.id)
    PostFrames.sanitize_frames(parsed, self)
    new_frames = PostFrames.format_frames(parsed)

    return if self.frames_pending == new_frames
#    self.old_rating = self.frames
    write_attribute(:frames_pending, new_frames)
    touch_change_seq!
  end

  def frames_api_data(data)
    return [] if data.empty?

    parsed = PostFrames.parse_frames(data, self.id)

    parsed.each_index do |idx|
      frame = parsed[idx]
      frame[:post_id] = self.id

      size = PostFrames.frame_image_dimensions(frame)
      frame[:width] = size[:width]
      frame[:height] = size[:height]

      size = PostFrames.frame_preview_dimensions(frame)
      frame[:preview_width] = size[:width]
      frame[:preview_height] = size[:height]

      filename = PostFrames.filename(frame)
      server = Mirrors.select_image_server(self.frames_warehoused, self.created_at.to_i+idx)
      frame[:url] = server + "/data/frame/#{filename}"

      thumb_server = Mirrors.select_image_server(self.frames_warehoused, self.created_at.to_i+idx, :use_aliases => true)
      frame[:preview_url] = thumb_server + "/data/frame-preview/#{filename}"
    end

    return parsed
  end
end

