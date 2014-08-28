module Post::ApiMethods
  attr_accessor :similarity

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
      :frames => frames_api_data(frames)
    }

    if status == "deleted"
      ret.delete(:sample_url)
      ret.delete(:jpeg_url)
      ret.delete(:file_url)
    end

    if status == "flagged" || status == "deleted" || status == "pending"
      ret[:flag_detail] = flag_detail

      if flag_detail then
        flag_detail.hide_user = (status == "deleted" && !Thread.current["danbooru-user"].is_mod_or_higher?)
      end
    end

    # For post/similar results:
    unless similarity.nil?
      ret[:similarity] = similarity
    end

    ret
  end

  def as_json(*args)
    api_attributes.as_json(*args)
  end

  def to_xml(options = {})
    api_attributes.to_xml(options.reverse_merge(:root => "post"))
  end

  def api_data
    {
      :post => self,
      :tags => Tag.batch_get_tag_types_for_posts([self])
    }
  end

  module ClassMethods
    # Remove attribute from params that shouldn't be changed through the API.
    def filter_api_changes(params)
      params.delete(:frames)
      params.delete(:frames_warehoused)
    end

    def batch_api_data(posts, options = {})
      result = { :posts => posts }
      unless options[:exclude_pools]
        result[:pool_posts] = PoolPost.active.where(:post_id => posts).includes(:pool)
        result[:pools] = result[:pool_posts].to_a.map(&:pool)
      end

      unless options[:exclude_tags]
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
      unless options[:exclude_votes] then
        vote_map = {}
        unless posts.empty? then
          votes = PostVote.where(:user_id => user.id, :post_id => posts)
          votes.each do |v|
            vote_map[v.post_id] = v.score
          end
        end
        result[:votes] = vote_map
      end

      result
    end
  end

  def self.included(m)
    m.extend(ClassMethods)
  end
end
