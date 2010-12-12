module PostApiMethods
  def api_attributes
    ret = {
      :id => id, 
      :tags => cached_tags, 
      :created_at => created_at.to_i, 
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
      :height => height,
      :is_held => is_held,
      :frames_pending_string => frames_pending,
      :frames_pending => frames_api_data(frames_pending),
      :frames_string => frames,
      :frames => frames_api_data(frames),
    }

    if status == "deleted"
      ret.delete(:sample_url)
      ret.delete(:jpeg_url)
      ret.delete(:file_url)
    end

    if status == "flagged" or status == "deleted"
      ret[:flag_detail] = flag_detail

      if flag_detail then
        flag_detail.hide_user = (status == "deleted" and not Thread.current["danbooru-user"].is_mod_or_higher?)
      end
    end

    # If we're being formatted as the contents of a pool, we'll have the pool_post
    # sequence loaded too.
    if self.respond_to?("pool_sequence") then
      ret[:pool_post] = {}
      ret[:pool_post][:pool_id] = pool_pool_id
      ret[:pool_post][:next_post_id] = pool_next_post_id
      ret[:pool_post][:prev_post_id] = pool_prev_post_id
      ret[:pool_post][:sequence] = pool_sequence
    end

    return ret
  end

  def to_json(*args)
    return api_attributes.to_json(*args)
  end

  def to_xml(options = {})
    return api_attributes.to_xml(options.reverse_merge(:root => "post"))
  end

  def api_data
    {
      :post => self,
      :tags => Tag.batch_get_tag_types_for_posts([self]),
    }
  end

  module ClassMethods
    # Remove attribute from params that shouldn't be changed through the API.
    def filter_api_changes(params)
      params.delete(:frames)
      params.delete(:frames_warehoused)
    end

    def batch_api_data(posts, options={})
      result = { :posts => posts }
      if not options[:exclude_tags] then
        result[:tags] = Tag.batch_get_tag_types_for_posts(posts)
      end

      if options.include?(:user)
        user = options[:user]
      else
        user = Thread.current["danbooru-user"]
      end

      # Allow loading votes along with the posts.
      #
      # The post data is cachable and vote data isn't, so keep this data separate from the
      # main post data to make it easier to cache API output later.
      if not options[:exclude_votes] then
        vote_map = {}
        if not posts.empty? then
          post_ids = posts.map { |p| p.id }.join(",")
          sql = "SELECT v.* FROM post_votes v WHERE v.user_id = %i AND v.post_id IN (%s)" % [user.id, post_ids]
          votes = PostVotes.find_by_sql(sql)
          votes.each { |v|
            vote_map[v.post_id] = v.score
          }
        end
        result[:votes] = vote_map
      end

      return result
    end
  end

  def self.included(m)
    m.extend(ClassMethods)
  end
end
