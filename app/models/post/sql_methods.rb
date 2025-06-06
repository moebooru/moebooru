module Post::SqlMethods
  module ClassMethods
    def find_by_tag_join(tag, options = {})
      joins(:_tags).where(tags: { name: tag.downcase.tr(" ", "_") })
        .limit(options[:limit])
        .offset(options[:offset])
        .order(options[:order] || { id: :desc })
    end

    def sql_range_for_where(parsed_query, field)
      conds = []
      params = []
      generate_sql_range_helper(parsed_query, field, conds, params)
      [ *conds, *params ]
    end

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

      when :in
        items = [ "?" ] * arr[1].length
        c << "#{field} IN (#{items.join(", ")})"
        p.concat(arr[1])

      end
    end

    def generate_sql(q, options = {})
      if q.is_a?(Hash)
        original_query = options[:original_query]
      else
        original_query = q
        q = Tag.parse_query(q)
      end

      conds = [ "true" ]
      joins = [ "posts p" ]
      join_params = []
      cond_params = []

      if q.key?(:error)
        conds << "FALSE"
      end

      generate_sql_range_helper(q[:ratio], "ratio", conds, cond_params)
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

      if q.key?(:show_deleted_only)
        if q[:show_deleted_only]
          conds << "p.status = 'deleted'"
        end
      elsif q[:post_id].empty?
        # If a specific post_id isn't specified, default to filtering deleted posts.
        conds << "p.status <> 'deleted'"
      end

      if q.key?(:parent_id) && q[:parent_id].is_a?(Integer)
        conds << "(p.parent_id = ? or p.id = ?)"
        cond_params << q[:parent_id]
        cond_params << q[:parent_id]
      elsif q.key?(:parent_id) && q[:parent_id] == false
        conds << "p.parent_id is null"
      end

      if q[:source].is_a?(String)
        conds << "lower(p.source) LIKE lower(?) ESCAPE E'\\\\'"
        cond_params << q[:source]
      end

      if q[:subscriptions].is_a?(String)
        /^(?<username>.+?):(?<subscription_name>.+)$/ =~ q[:subscriptions]
        username ||= q[:subscriptions]
        user = User.find_by_name(username)

        if user
          post_ids = TagSubscription.find_post_ids(user.id, subscription_name)
          conds << "p.id IN (?)"
          cond_params << post_ids
        end
      end

      if q[:fav].is_a?(String)
        joins << "JOIN favorites f ON f.post_id = p.id JOIN users fu ON f.user_id = fu.id"
        conds << "lower(fu.name) = lower(?)"
        cond_params << q[:fav]
      end

      if q.key?(:vote_negated)
        joins << "LEFT JOIN post_votes v ON p.id = v.post_id AND v.user_id = ?"
        join_params << q[:vote_negated]
        conds << "v.score IS NULL"
      end

      if q.key?(:vote)
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

      if q.key?(:exclude_pools)
        q[:exclude_pools].each_index do |i|
          if q[:exclude_pools][i].is_a?(Integer)
            joins << "LEFT JOIN pools_posts ep#{i} ON (ep#{i}.active AND ep#{i}.post_id = p.id AND ep#{i}.pool_id = ?)"
            join_params << q[:exclude_pools][i]
            conds << "ep#{i} IS NULL"
          end

          if q[:exclude_pools][i].is_a?(String)
            joins << "LEFT JOIN pools_posts ep#{i} ON (ep#{i}.active AND ep#{i}.post_id = p.id) LEFT JOIN pools epp#{i} ON (ep#{i}.pool_id = epp#{i}.id AND epp#{i}.name ILIKE ? ESCAPE E'\\\\')"
            join_params << ("%" + q[:exclude_pools][i].to_escaped_for_sql_like + "%")
            conds << "ep#{i} IS NULL"
          end
        end
      end

      if q.key?(:pool)
        conds << "pools_posts.active = true"

        unless q.key?(:order)
          pool_ordering = " ORDER BY pools_posts.pool_id ASC, nat_sort(pools_posts.sequence), pools_posts.post_id"
        end

        if q[:pool].is_a?(Integer)
          joins << "JOIN pools_posts ON pools_posts.post_id = p.id JOIN pools ON pools_posts.pool_id = pools.id"
          conds << "pools.id = ?"
          cond_params << q[:pool]
        end

        if q[:pool].is_a?(String)
          if q[:pool] == "*"
            joins << "JOIN pools_posts ON pools_posts.post_id = p.id JOIN pools ON pools_posts.pool_id = pools.id"
          else
            joins << "JOIN pools_posts ON pools_posts.post_id = p.id JOIN pools ON pools_posts.pool_id = pools.id"
            conds << "pools.name ILIKE ? ESCAPE E'\\\\'"
            cond_params << ("%" + q[:pool].to_escaped_for_sql_like + "%")
          end
        end
      end

      if q[:include].any?
        conds << "tags_array && ARRAY[?]::varchar[]"
        cond_params << Array(q[:include])
      end

      if q[:related].any?
        raise "You cannot search for more than #{CONFIG["tag_query_limit"]} tags at a time" if q[:related].size > CONFIG["tag_query_limit"]
        conds << "tags_array @> ARRAY[?]::varchar[]"
        cond_params << Array(q[:related])
      end

      if q[:exclude].any?
        raise "You cannot search for more than #{CONFIG["tag_query_limit"]} tags at a time" if q[:exclude].size > CONFIG["tag_query_limit"]
        conds << "NOT tags_array && ARRAY[?]::varchar[]"
        cond_params << Array(q[:exclude])
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

      if q.key?(:show_holds)
        if q[:show_holds] == :only
          conds << "p.is_held"
        elsif q[:show_holds] == :hide
          conds << "NOT p.is_held"
        elsif q[:show_holds] == :yes
        end
      else
        # Hide held posts by default only when not using the API.
        unless options[:from_api]
          conds << "NOT p.is_held"
        end
      end

      if q.key?(:show_pending)
        if q[:show_pending] == :only
          conds << "p.status = 'pending'"
        elsif q[:show_pending] == :hide
          conds << "p.status <> 'pending'"
        elsif q[:show_pending] == :yes
        end
      else
        # Hide pending posts by default only when not using the API.
        if CONFIG["hide_pending_posts"] && !options[:from_api] && !options[:pending]
          conds << "p.status <> 'pending'"
        end
      end

      if q.key?(:shown_in_index)
        if q[:shown_in_index]
          conds << "p.is_shown_in_index"
        else
          conds << "NOT p.is_shown_in_index"
        end
      elsif original_query.blank? && !options[:from_api]
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
      end

      sql << " FROM " + joins.join(" ")
      sql << " WHERE " + conds.join(" AND ")

      if q.key?(:order) && !options[:count]
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
          sql << " ORDER BY ratio"

        when "landscape"
          sql << " ORDER BY ratio DESC"

        when "portrait_pool"
          # We can only do this if we're searching for a pool.
          if q.key?(:pool)
            sql << " ORDER BY ratio, nat_sort(pools_posts.sequence), pools_posts.post_id"
          end

        when "change", "change_asc"
          sql << " ORDER BY change_seq"

        when "change_desc"
          sql << " ORDER BY change_seq DESC"

        when "vote"
          if q.key?(:vote)
            sql << " ORDER BY v.updated_at DESC"
          end

        when "fav"
          if q[:fav].is_a?(String)
            sql << " ORDER BY f.id DESC"
          end

        when "random"
          options[:offset] = nil
          sql << " ORDER BY random()"

        else
          use_default_order = true
        end
      else
        use_default_order = true
      end

      if use_default_order && !options[:count]
        if pool_ordering
          sql << pool_ordering
        else
          if options[:from_api]
            # When using the API, default to sorting by ID.
            sql << " ORDER BY p.id DESC"
          else
            sql << " ORDER BY p.index_timestamp DESC"
          end
        end
      end

      if options[:limit]
        sql << " LIMIT " + options[:limit].to_s
      end

      if options[:offset]
        sql << " OFFSET " + options[:offset].to_s
      end

      params = join_params + cond_params

      Post.sanitize_sql_array([ sql, *params ])
    end
  end

  def self.included(m)
    m.extend(ClassMethods)
  end
end
