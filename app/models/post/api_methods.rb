module PostApiMethods
  def api_attributes
    ret = {
      :id => id, 
      :tags => cached_tags, 
      :created_at => created_at, 
      :creator_id => user_id, 
      :author => author,
      :change => change_seq,
      :source => source, 
      :score => score, 
      :md5 => md5, 
      :file_size => file_size,
      :file_url => file_url, 
      :is_shown_in_index => is_shown_in_index,
      :preview_url => preview_url, 
      :preview_width => preview_dimensions[0],
      :preview_height => preview_dimensions[1],
      :actual_preview_width => raw_preview_dimensions[0],
      :actual_preview_height => raw_preview_dimensions[1],
      :sample_url => sample_url,
      :sample_width => sample_width || width,
      :sample_height => sample_height || height,
      :sample_file_size => sample_size,
      :jpeg_url => jpeg_url,
      :jpeg_width => jpeg_width || width,
      :jpeg_height => jpeg_height || height,
      :jpeg_file_size => jpeg_size,
      :rating => rating, 
      :has_children => has_children, 
      :parent_id => parent_id, 
      :status => status,
      :width => width,
      :height => height
    }

    if status == "flagged"
      ret[:flag_detail] = flag_detail
    end

    # If we're being formatted as the contents of a pool, we'll have the pool_post
    # sequence loaded too.
    ret[:sequence] = sequence if self.respond_to?("sequence")

    return ret
  end

  def to_json(*args)
    return api_attributes.to_json(*args)
  end

  def to_xml(options = {})
    return api_attributes.to_xml(options.merge(:root => "post"))
  end
end
