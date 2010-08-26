module PostSqlMethods
  module ClassMethods
    def generate_sql_range_helper(arr, field, c, p)
      case arr[0]
      when :eq
        c << "#{field} = ?"
        p << arr[1]

      when :gt
        c << "#{field} > ?"
        p << arr[1]
    
      when :gte
        c << "#{field} >= ?"
        p << arr[1]

      when :lt
        c << "#{field} < ?"
        p << arr[1]

      when :lte
        c << "#{field} <= ?"
        p << arr[1]

      when :between
        c << "#{field} BETWEEN ? AND ?"
        p << arr[1]
        p << arr[2]

      else
        # do nothing
      end
    end

    def generate_sql(q, options = {})
      if q.is_a?(Hash)
        original_query = options[:original_query]
      else
        original_query = q
        q = Tag.parse_query(q)
      end

      conds = ["true"]
      joins = ["posts p"]
      join_params = []
      cond_params = []

      if q.has_key?(:error)
        conds << "FALSE"
      end

      generate_sql_range_helper(q[:post_id], "p.id", conds, cond_params)
      generate_sql_range_helper(q[:mpixels], "p.width*p.height/1000000.0", conds, cond_params)
      generate_sql_range_helper(q[:width], "p.width", conds, cond_params)
      generate_sql_range_helper(q[:height], "p.height", conds, cond_params)
      generate_sql_range_helper(q[:score], "p.score", conds, cond_params)
      generate_sql_range_helper(q[:date], "p.created_at::date", conds, cond_params)
      generate_sql_range_helper(q[:change], "p.change_seq", conds, cond_params)

      if q[:md5].is_a?(String)
        conds << "p.md5 IN (?)"
        cond_params << q[:md5].split(/,/)
      end
    
      if q[:ext].is_a?(String)
        conds << "p.file_ext IN (?)"
        cond_params << q[:ext].downcase.split(/,/)
      end
    
      if q[:deleted_only] == true
        conds << "p.status = 'deleted'"
      else
        conds << "p.status <> 'deleted'"
      end

      if q.has_key?(:parent_id) && q[:parent_id].is_a?(Integer)
        conds << "(p.parent_id = ? or p.id = ?)"
        cond_params << q[:parent_id]
        cond_params << q[:parent_id]
      elsif q.has_key?(:parent_id) && q[:parent_id] == false
        conds << "p.parent_id is null"
      end

      if q[:source].is_a?(String)
        conds << "p.source LIKE ? ESCAPE E'\\\\'"
        cond_params << q[:source]
      end

      if q[:favtag].is_a?(String)
        user = User.find_by_name(q[:favtag])

        if user
          post_ids = FavoriteTag.find_post_ids(user.id)
          conds << "p.id IN (?)"
          cond_params << post_ids
        end
      end

      if q[:fav].is_a?(String)
        joins << "JOIN favorites f ON f.post_id = p.id JOIN users fu ON f.user_id = fu.id"
        conds << "lower(fu.name) = lower(?)"
        cond_params << q[:fav]
      end

      if q.has_key?(:vote_negated)
        joins << "LEFT JOIN post_votes v ON p.id = v.post_id AND v.user_id = ?"
        join_params << q[:vote_negated]
        conds << "v.score IS NULL"
      end

      if q.has_key?(:vote)
        joins << "JOIN post_votes v ON p.id = v.post_id"
        conds << "v.user_id = ?"
        cond_params << q[:vote][1]

        generate_sql_range_helper(q[:vote][0], "v.score", conds, cond_params)
      end

      if q[:user].is_a?(String)
        joins << "JOIN users u ON p.user_id = u.id"
        conds << "lower(u.name) = lower(?)"
        cond_params << q[:user]
      end

      if q.has_key?(:exclude_pools)
        q[:exclude_pools].each_index do |i|
          if q[:exclude_pools][i].is_a?(Integer)
            joins << "LEFT JOIN pools_posts ep#{i} ON (ep#{i}.post_id = p.id AND ep#{i}.pool_id = ?)"
            join_params << q[:exclude_pools][i]
            conds << "ep#{i} IS NULL"
          end

          if q[:exclude_pools][i].is_a?(String)
            joins << "LEFT JOIN pools_posts ep#{i} ON ep#{i}.post_id = p.id LEFT JOIN pools epp#{i} ON (ep#{i}.pool_id = epp#{i}.id AND epp#{i}.name ILIKE ? ESCAPE E'\\\\')"
            join_params << ("%" + q[:exclude_pools][i].to_escaped_for_sql_like + "%")
            conds << "ep#{i} IS NULL"
          end
        end
      end

      if q.has_key?(:pool)
        if q.has_key?(:pool_posts)
          if q[:pool_posts] == "all"
            conds << "(pools_posts.active OR pools_posts.master_id IS NOT NULL)"
          elsif q[:pool_posts] == "master"
            conds << "(pools_posts.master_id IS NOT NULL)"
          elsif q[:pool_posts] == "slave"
            conds << "(pools_posts.active AND pools_posts.slave_id IS NOT NULL)"
          end
        elsif q.has_key?(:pool_posts) && q[:pool_posts] == "orig"
          conds << "pools_posts.active = true"
        else
          conds << "((pools_posts.active = true AND pools_posts.slave_id IS NULL) OR pools_posts.master_id IS NOT NULL)"
        end

        if not q.has_key?(:order)
          pool_ordering = " ORDER BY pools_posts.pool_id ASC, nat_sort(pools_posts.sequence), pools_posts.post_id"
        end

        if q[:pool].is_a?(Integer)
          joins << "JOIN pools_posts ON pools_posts.post_id = p.id JOIN pools ON pools_posts.pool_id = pools.id"
          conds << "pools.id = ?"
          cond_params << q[:pool]
        end

        if q[:pool].is_a?(String)
          joins << "JOIN pools_posts ON pools_posts.post_id = p.id JOIN pools ON pools_posts.pool_id = pools.id"
          conds << "pools.name ILIKE ? ESCAPE E'\\\\'"
          cond_params << ("%" + q[:pool].to_escaped_for_sql_like + "%")
        end
      end

      if q.has_key?(:include)
        joins << "JOIN posts_tags ipt ON ipt.post_id = p.id"
        conds << "ipt.tag_id IN (SELECT id FROM tags WHERE name IN (?))"
        cond_params << (q[:include] + q[:related])
      elsif q[:related].any?
        raise "You cannot search for more than #{CONFIG['tag_query_limit']} tags at a time" if q[:related].size > CONFIG["tag_query_limit"]
      
        q[:related].each_with_index do |rtag, i|
          joins << "JOIN posts_tags rpt#{i} ON rpt#{i}.post_id = p.id AND rpt#{i}.tag_id = (SELECT id FROM tags WHERE name = ?)"
          join_params << rtag
        end
      end

      if q[:exclude].any?
        raise "You cannot search for more than #{CONFIG['tag_query_limit']} tags at a time" if q[:exclude].size > CONFIG["tag_query_limit"]
        q[:exclude].each_with_index do |etag, i|
          joins << "LEFT JOIN posts_tags ept#{i} ON p.id = ept#{i}.post_id AND ept#{i}.tag_id = (SELECT id FROM tags WHERE name = ?)"
          conds << "ept#{i}.tag_id IS NULL"
          join_params << etag
        end
      end

      if q[:rating].is_a?(String)
        case q[:rating][0, 1].downcase
        when "s"
          conds << "p.rating = 's'"

        when "q"
          conds << "p.rating = 'q'"

        when "e"
          conds << "p.rating = 'e'"
        end
      end

      if q[:rating_negated].is_a?(String)
        case q[:rating_negated][0, 1].downcase
        when "s"
          conds << "p.rating <> 's'"

        when "q"
          conds << "p.rating <> 'q'"

        when "e"
          conds << "p.rating <> 'e'"
        end
      end

      if q[:unlocked_rating] == true
        conds << "p.is_rating_locked = FALSE"
      end

      if options[:pending]
        conds << "p.status = 'pending'"
      end
    
      if options[:flagged]
        conds << "p.status = 'flagged'"
      end

      if q.has_key?(:show_holds_only)
        if q[:show_holds_only]
          conds << "p.is_held"
        end
      else
	# Hide held posts by default only when not using the API.
	if not options[:from_api] then
	  conds << "NOT p.is_held"
	end
      end

      if q.has_key?(:shown_in_index)
        if q[:shown_in_index]
          conds << "p.is_shown_in_index"
        else
          conds << "NOT p.is_shown_in_index"
        end
      elsif original_query.blank? and not options[:from_api]
	# Hide not shown posts by default only when not using the API.
        conds << "p.is_shown_in_index"
      end

      sql = "SELECT "

      if options[:count]
        sql << "COUNT(*)"
      elsif options[:select]
        sql << options[:select]
      else
        sql << "p.*"

	# If we're searching in a pool, include the pool_post sequence in API output.
	if q.has_key?(:pool)
	  sql << ", pools_posts.sequence AS sequence"
	end
      end

      sql << " FROM " + joins.join(" ")
      sql << " WHERE " + conds.join(" AND ")

      if q[:order] && !options[:count]
        case q[:order]
        when "id"
          sql << " ORDER BY p.id"
        
        when "id_desc"
          sql << " ORDER BY p.id DESC"
        
        when "score"
          sql << " ORDER BY p.score DESC"
        
        when "score_asc"
          sql << " ORDER BY p.score"
        
        when "mpixels"
          # Use "w*h/1000000", even though "w*h" would give the same result, so this can use
          # the posts_mpixels index.
          sql << " ORDER BY width*height/1000000.0 DESC"

        when "mpixels_asc"
          sql << " ORDER BY width*height/1000000.0"

        when "portrait"
          sql << " ORDER BY 1.0*width/GREATEST(1, height)"

        when "landscape"
          sql << " ORDER BY 1.0*width/GREATEST(1, height) DESC"

        when "change", "change_asc"
          sql << " ORDER BY change_seq"

        when "change_desc"
          sql << " ORDER BY change_seq DESC"

        when "vote"
          if q.has_key?(:vote)
            sql << " ORDER BY v.updated_at DESC"
          end

        when "fav"
          if q[:fav].is_a?(String)
            sql << " ORDER BY f.id DESC"
          end

        when "random"
          sql << " ORDER BY random"

        else
          if pool_ordering
            sql << pool_ordering
          else
	    if options[:from_api] then
	      # When using the API, default to sorting by ID.
	      sql << " ORDER BY p.id DESC"
	    else
	      sql << " ORDER BY p.index_timestamp DESC"
	    end
          end
        end
      elsif options[:order]
        sql << " ORDER BY " + options[:order]
      end

      if options[:limit]
        sql << " LIMIT " + options[:limit].to_s
      end

      if options[:offset]
        sql << " OFFSET " + options[:offset].to_s
      end

      params = join_params + cond_params
      return Post.sanitize_sql([sql, *params])
    end
  end
  
  def self.included(m)
    m.extend(ClassMethods)
  end
end
