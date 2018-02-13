module Tag::ParseMethods
  module ClassMethods
    def scan_query(query)
      query.to_s.to_valid_utf8.downcase.split.uniq
    end

    def scan_tags(tags)
      tags.to_s.gsub(/[%,]/, "").downcase.scan(/\S+/).uniq
    end

    def parse_cast(x, type)
      if type == :integer
        x.to_i
      elsif type == :float
        x.to_f
      elsif type == :date
        begin
          x.to_date
        rescue
          nil
        end
      end
    end

    def parse_helper(range, type = :integer)
      # "1", "0.5", "5.", ".5":
      # (-?(\d+(\.\d*)?|\d*\.\d+))
      case range
      when /^(.+?)\.\.(.+)/
        return [:between, parse_cast(Regexp.last_match[1], type), parse_cast(Regexp.last_match[2], type)]

      when /^<=(.+)/, /^\.\.(.+)/
        return [:lte, parse_cast(Regexp.last_match[1], type)]

      when /^<(.+)/
        return [:lt, parse_cast(Regexp.last_match[1], type)]

      when /^>=(.+)/, /^(.+)\.\.$/
        return [:gte, parse_cast(Regexp.last_match[1], type)]

      when /^>(.+)/
        return [:gt, parse_cast(Regexp.last_match[1], type)]

      when /^(.+?),(.+)/
        items = range.split(",").map do |val|
          parse_cast(val, type)
        end

        return [:in, items]

      else
        return [:eq, parse_cast(range, type)]

      end
    end

    # Parses a query into three sets of tags: reject, union, and intersect.
    #
    # === Parameters
    # * +query+: String, array, or nil. The query to parse.
    # * +options+: A hash of options.
    def parse_query(query, options = {})
      q = Hash.new { |h, k| h[k] = [] }

      scan_query(query).each do |token|
        if token =~ /^([qse])$/
          q[:rating] = Regexp.last_match[1]
          next
        end

        if token =~ /^(unlocked|deleted|ext|user|sub|vote|-vote|fav|md5|-rating|rating|width|height|mpixels|score|source|id|date|pool|-pool|parent|order|change|holds|pending|shown|limit):(.+)$/
          if Regexp.last_match[1] == "user"
            q[:user] = Regexp.last_match[2]
          elsif Regexp.last_match[1] == "vote"
            vote, user = Regexp.last_match[2].split(":", 2)
            user_id = User.find_by_name(user).id rescue nil
            q[:vote] = [parse_helper(vote), user_id]
          elsif Regexp.last_match[1] == "-vote"
            q[:vote_negated] = User.find_by_name(Regexp.last_match[2]).id rescue nil
            q[:error] = "no user named %s" % user if q[:vote_negated].nil?
          elsif Regexp.last_match[1] == "fav"
            q[:fav] = Regexp.last_match[2]
          elsif Regexp.last_match[1] == "sub"
            q[:subscriptions] = Regexp.last_match[2]
          elsif Regexp.last_match[1] == "md5"
            q[:md5] = Regexp.last_match[2]
          elsif Regexp.last_match[1] == "-rating"
            q[:rating_negated] = Regexp.last_match[2]
          elsif Regexp.last_match[1] == "rating"
            q[:rating] = Regexp.last_match[2]
          elsif Regexp.last_match[1] == "id"
            q[:post_id] = parse_helper(Regexp.last_match[2])
          elsif Regexp.last_match[1] == "width"
            q[:width] = parse_helper(Regexp.last_match[2])
          elsif Regexp.last_match[1] == "height"
            q[:height] = parse_helper(Regexp.last_match[2])
          elsif Regexp.last_match[1] == "mpixels"
            q[:mpixels] = parse_helper(Regexp.last_match[2], :float)
          elsif Regexp.last_match[1] == "score"
            q[:score] = parse_helper(Regexp.last_match[2])
          elsif Regexp.last_match[1] == "source"
            q[:source] = Regexp.last_match[2].to_escaped_for_sql_like + "%"
          elsif Regexp.last_match[1] == "date"
            q[:date] = parse_helper(Regexp.last_match[2], :date)
          elsif Regexp.last_match[1] == "pool"
            q[:pool] = Regexp.last_match[2]
            if q[:pool] =~ /^(\d+)$/
              q[:pool] = q[:pool].to_i
            end
          elsif Regexp.last_match[1] == "-pool"
            pool = Regexp.last_match[2]
            if pool =~ /^(\d+)$/
              pool = pool.to_i
            end
            q[:exclude_pools] ||= []
            q[:exclude_pools] << pool
          elsif Regexp.last_match[1] == "parent"
            if Regexp.last_match[2] == "none"
              q[:parent_id] = false
            else
              q[:parent_id] = Regexp.last_match[2].to_i
            end
          elsif Regexp.last_match[1] == "order"
            q[:order] = Regexp.last_match[2]
          elsif Regexp.last_match[1] == "unlocked"
            if Regexp.last_match[2] == "rating"
              q[:unlocked_rating] = true
            end
          elsif Regexp.last_match[1] == "deleted"
            # This naming is slightly odd, to retain API compatibility with Danbooru's "deleted:true"
            # search flag.
            if Regexp.last_match[2] == "true"
              q[:show_deleted_only] = true
            else Regexp.last_match[2] == "all"
                 q[:show_deleted_only] = false # all posts, deleted or not
            end
          elsif Regexp.last_match[1] == "ext"
            q[:ext] = Regexp.last_match[2]
          elsif Regexp.last_match[1] == "change"
            q[:change] = parse_helper(Regexp.last_match[2])
          elsif Regexp.last_match[1] == "shown"
            q[:shown_in_index] = (Regexp.last_match[2] == "true")
          elsif Regexp.last_match[1] == "holds"
            if Regexp.last_match[2] == "true" || Regexp.last_match[2] == "only"
              q[:show_holds] = :only
            elsif Regexp.last_match[2] == "all"
              q[:show_holds] = :yes # all posts, held or not
            elsif Regexp.last_match[2] == "false"
              q[:show_holds] = :hide
            end
          elsif Regexp.last_match[1] == "pending"
            if Regexp.last_match[2] == "true" || Regexp.last_match[2] == "only"
              q[:show_pending] = :only
            elsif Regexp.last_match[2] == "all"
              q[:show_pending] = :yes # all posts, pending or not
            elsif Regexp.last_match[2] == "false"
              q[:show_pending] = :hide
            end
          elsif Regexp.last_match[1] == "limit"
            q[:limit] = Regexp.last_match[2]
          end
        elsif token[0] == "-" && token.size > 1
          q[:exclude] << token[1..-1]
        elsif token[0] == "~" && token.size > 1
          q[:include] << token[1..-1]
        elsif token.include?("*")
          matches = where("name LIKE ?", token.to_escaped_for_sql_like).select(:name, :post_count).limit(25).order(:post_count => :desc).pluck(:name)
          matches = ["~no_matches~"] if matches.empty?
          q[:include] += matches
        else
          q[:related] << token
        end
      end

      unless options[:skip_aliasing]
        q[:exclude] = TagAlias.to_aliased(q[:exclude]) if q.key?(:exclude)
        q[:include] = TagAlias.to_aliased(q[:include]) if q.key?(:include)
        q[:related] = TagAlias.to_aliased(q[:related]) if q.key?(:related)
      end

      q
    end
  end

  def self.included(m)
    m.extend(ClassMethods)
  end
end
