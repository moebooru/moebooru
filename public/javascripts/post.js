Post = {
  posts: new Hash(),

	find_similar: function() {
		var old_source_name = $("post_source").name
		var old_file_name = $("post_file").name
		var old_target = $("edit-form").target
		var old_action = $("edit-form").action

		$("post_source").name = "url"
		$("post_file").name = "file"
		$("edit-form").target = "_blank"
		$("edit-form").action = "http://danbooru.iqdb.hanyuu.net/"

		$("edit-form").submit()		
		
		$("post_source").name = old_source_name
		$("post_file").name = old_file_name
		$("edit-form").target = old_target
		$("edit-form").action = old_action
	},

  approve: function(post_id) {
    notice("Approving post #" + post_id)
    var params = {}
    params["ids[" + post_id + "]"] = "1"
    params["commit"] = "Approve"
    
    new Ajax.Request("/post/moderate.json", {
      parameters: params,
      
      onComplete: function(resp) {
        var resp = resp.responseJSON
        
        if (resp.success) {
          notice("Post approved")
          if ($("p" + post_id)) {
            $("p" + post_id).removeClassName("pending")
          }
          if ($("pending-notice")) {
            $("pending-notice").hide()
          }
        } else {
          notice("Error: " + resp.reason)
        }
      }
    })
  },

  applied_list: [],
  reset_tag_script_applied: function() {
    for(var i=0; i < Post.applied_list.length; ++i)
      Post.applied_list[i].removeClassName("tag-script-applied");

    Post.applied_list = []
  },

  /*
   * posts is an array of the form:
   *
   * [{ id: 123, tags: "tags", old_tags: "tags2" },
   *  { id: 124, tags: "tags3", old_tags: "tags4" }]
   *
   * and we pass it as a query string that results in:
   *
   * [{ :id="123", :tags = "tags", :old_tags => "tags2" },
   *  { :id="124", :tags = "tags3", :old_tags => "tags4" }]
   *
   * Prototype won't generate a query string to do this.  We also need to hack Prototype
   * to keep it from messing around with the parameter order (bug).
   *
   * One significant difference between using this and update() is that this will
   * receive secondary updates: if you change a parent with this function, the parent
   * will have its styles (border color) updated.  update() only receives the results
   * of the post that actually changed, and won't update other affected posts.
   */
  update_batch: function(posts, finished) {
    var original_count = posts.length;

    /* posts is a hash of id: { post }.  Convert this to a Rails-format object array. */
    var params_array = [];                  
    posts.each(function(post) {
      $H(post).each(function(pair2) {
        var s = "post[][" + pair2.key + "]=" + window.encodeURIComponent(pair2.value);
        params_array.push(s);
      });
    });

    var params = params_array.join("&");

    new Ajax.Request('/post/update_batch.json', {
      parameters: params,

      onComplete: function(resp) {
        var resp = resp.responseJSON

        if (resp.success) {
          // Update the stored posts.
          resp.posts.each(function(post) {
            /* Only register posts that we already knew about.  We may receive information about
             * posts that we don't care about (new parent posts that aren't displayed in our index). */
            if(Post.posts.get(post.id))
              Post.register(post)
            Post.update_styles(post);
          });

          notice((original_count == 1? "Post": "Posts") + " updated");

          if(finished)
            finished(resp.posts);
        }
      }
    });
  },

  update_styles: function(post)
  {
    var e = $("p" + post.id);
    if(!e) return;
    if(post["has_children"])
      e.addClassName("has-children");
    else
      e.removeClassName("has-children");

    if(post["parent_id"])
      e.addClassName("has-parent");
    else
      e.removeClassName("has-parent");
  },

  update: function(post_id, params, finished) {
    notice('Updating post #' + post_id)
    params["id"] = post_id

    new Ajax.Request('/post/update.json', {
      parameters: params,

      onComplete: function(resp) {
        var resp = resp.responseJSON

        if (resp.success) {
          notice('Post updated')

          // Update the stored post.
          Post.register(resp.post)

          Post.update_styles(resp.post);

          var element = element = $$("#p" + post_id + " > .directlink")
          if (element.length > 0) {
            element[0].addClassName("tag-script-applied")
            Post.applied_list.push(element[0])
          }

          if(finished)
            finished(resp.post);
        } else {
          notice('Error: ' + resp.reason)
        }
      }
    })
  },

  activate_posts: function(post_ids, finished)
  {
    notice("Activating " + post_ids.length + (post_ids.length == 1? " post":" posts"));
    var params = {};
    params["post_ids[]"] = post_ids

    new Ajax.Request('/post/activate.json', {
      parameters: params,

      onComplete: function(resp) {
        var resp = resp.responseJSON

        if (resp.success) {
          if(finished)
            finished(resp);
        } else {
          notice('Error: ' + resp.reason)
        }
      }
    })
  },

  activate_all_posts: function()
  {
    var post_ids = [];
    Post.posts.each(function(pair) {
      post_ids.push(pair.key);
    });
    Post.activate_posts(post_ids, function(resp) {
      if(resp.count == 0)
        notice("No posts were activated.");
      else
        notice(resp.count + (resp.count == 1? " post":" posts") + " activated");
    });
  },

  /* Activating a single post uses post/update, which returns the finished post, so we can
   * check if the change was made.  activate_posts uses post/activate, which works in bulk
   * and doesn't return errors for individual posts. */
  activate_post: function(post_id)
  {
     Post.update(post_id, { "post[is_held]": false }, function(post)
     {
       if(post.is_held)
         notice("Couldn't activate post");
       else
         $("held-notice").remove();
     });
  },


  vote_set_stars: function(vote, temp, container) {
    container = Post.get_vote_container(container);

    if(!temp && $("add-to-favs"))
    {
      if (vote >= 3) {
        $("add-to-favs").hide()
        $("remove-from-favs").show()
      } else {
        $("remove-from-favs").hide()
        $("add-to-favs").show()
      }
    }

    var stars = container.down(".stars").select("a")
    stars.each(function(star) {
      var matches = star.className.match(/^.* star-(\d+)$/)
      if(!matches)
        return;
      var star_vote = parseInt(matches[1])
      var on = star.down(".score-on")
      var off = star.down(".score-off")

      if (vote != null && vote >= star_vote)
      {
        on.addClassName("score-visible");
        off.removeClassName("score-visible");
      }
      else
      {
        on.removeClassName("score-visible");
        off.addClassName("score-visible");
      }
    })
  },

  vote_mouse_over: function(desc, container, vote) {
    container = Post.get_vote_container(container);
    Post.vote_set_stars(vote, true, container);
    container.down(".vote-desc").update(desc);
  },
	
  vote_mouse_out: function(desc, container, vote) {
    container = Post.get_vote_container(container);
    Post.vote_set_stars(container.current_vote, false, container);
    container.down(".vote-desc").update();
  },

  init_vote: function(post_id, vote, container) {
    container = Post.get_vote_container(container);
    container.vote_post_id = post_id;
    container.current_vote = vote;
    Post.vote_set_stars(vote, false, container);
  },

  init_vote_hotkeys: function(post_id, container)
  {
    OnKey(192, null, function(e) { Post.vote(container, +0); return true; }.bindAsEventListener(this)); // `
    OnKey(49, null, function(e) { Post.vote(container, +1); return true; }.bindAsEventListener(this));
    OnKey(50, null, function(e) { Post.vote(container, +2); return true; }.bindAsEventListener(this));
    OnKey(51, null, function(e) { Post.vote(container, +3); return true; }.bindAsEventListener(this));
  },

  get_vote_container: function(stars)
  {
    if(!stars.hasClassName("vote-container"))
      stars = stars.up(".vote-container");
    if(!stars)
      throw "Couldn't find .vote-container element";
    return stars;
  },

  get_vote_post_id: function(stars)
  {
    stars = Post.get_vote_container(stars);
    return stars.vote_post_id;
  },

  init_vote_widgets: function() {
    var vote_descs =
    {
      "0": "Neutral",
      "1": "Good",
      "2": "Great",
      "3": "Favorite"
    };

    $$(".stars").each(function(stars)
    {
      if(stars.initialized_widget)
        return;
      stars.initialized_widget = true;

      if(stars.down(".remove-vote"))
      {
        stars.down(".remove-vote").on("mouseover", function(e) { Post.vote_mouse_over('Remove vote', e.target, 0); });
        stars.down(".remove-vote").on("mouseout", function(e) { Post.vote_mouse_out('Remove vote', e.target, 0); });
        stars.down(".remove-vote").on("click", function(e) { e.stop(); Post.widget_vote(e.target, 0); });
      }

      if(stars.down(".vote-up-anonymous"))
        stars.down(".vote-up-anonymous").on("click", function(e) { e.stop(); Post.widget_vote(e.target, +1); });

      if(stars.down(".vote-up"))
        stars.down(".vote-up").on("click", function(e) { e.stop(); Post.widget_vote_up(e.target); });

      stars.select(".star").each(function(s) {
        var vote_match = s.className.match(/.* star-(\d+)/);
        if(!vote_match)
          return;
        var vote = parseInt(vote_match[1]);

        var desc = vote_descs[vote];
        s.on("click", function(e) { e.stop(); Post.widget_vote(e.target, vote); });
        s.on("mouseover", function(e) { Post.vote_mouse_over(desc, e.target, vote); });
        s.on("mouseout", function(e) { Post.vote_mouse_out(desc, e.target, vote); });
      });
    });
  },

  widget_vote_up: function(container) {
    container = Post.get_vote_container(container);
    return Post.vote(container, container.current_vote + 1);
  },
  widget_vote: function(container, score) {
    return Post.vote(container, score);
  },

  vote: function(container, score) {
    if(score > 3)
      return;
    
    container = Post.get_vote_container(container);
    var post_id = Post.get_vote_post_id(container);
    notice("Voting...")

    options = {
            "id": post_id,
            "score": score
    }
    
    new Ajax.Request("/post/vote.json", {
      parameters: options,

      onComplete: function(resp) {
        var resp = resp.responseJSON

        if (resp.success) {
          if(container.vote_post_id == post_id)
          {
            $("post-score-" + resp.post_id).update(resp.score)

            container.current_vote = score;
            Post.vote_set_stars(resp.vote, false, container);

            if ($("favorited-by")) {
              $("favorited-by").update(Favorite.link_to_users(resp.votes["3"]))
            }
          }
          notice("Vote saved")
        } else {
          notice(resp.reason)
        }
      }
    })
  },

  flag: function(id) {
    var reason = prompt("Why should this post be flagged for deletion?", "")

    if (!reason) {
      return false
    }
  
    new Ajax.Request("/post/flag.json", {
      parameters: {
        "id": id,
        "reason": reason
      },
    
      onFailure: function(req) {
        var resp = req.responseJSON
	notice(resp.reason);
      },

      onSuccess: function(req) {
        notice("Post was flagged for deletion")
        $("p" + id).addClassName("flagged")
      }
    })
  },

  observe_text_area: function(field_id) {
    $(field_id).observe("keydown", function(e) {
      if (e.keyCode == Event.KEY_RETURN) {
        this.up("form").submitWithLogin()
        e.stop()
      }
    })
  },

  register: function(post) {
    post.tags = post.tags.match(/\S+/g) || []
    post.match_tags = post.tags.clone()
    post.match_tags.push("rating:" + post.rating.charAt(0))
    post.match_tags.push("status:" + post.status)

    if(Post.post_tags)
    {
      /* Group tags by type. */
      post.tags_by_type = new Hash;

      post.tags.each(function(tag)
      {
        var tag_type = Post.post_tags[tag];

	/* We can end up not knowing a tag's type due to tag script editing giving us
	 * tags we weren't told the type of. */
	if(!tag_type)
          tag_type = "general";
        var list = post.tags_by_type.get(tag_type);
        if(!list)
        {
          list = [];
          post.tags_by_type.set(tag_type, list);
        }
        list.push(tag);
      });
    };

    this.posts.set(post.id, post)
  },

  unregister_all: function() {
    this.posts = new Hash();
  },

  blacklists: [],

  is_blacklisted: function(post_id) {
    var post = this.posts.get(post_id)
    var has_tag = post.match_tags.member.bind(post.match_tags)
    return Post.blacklists.any(function(b) {
      return (b.require.all(has_tag) && !b.exclude.any(has_tag))
    })
  },

  apply_blacklists: function() {	
    Post.blacklists.each(function(b) { b.hits = 0 })

    var count = 0
    Post.posts.each(function(pair) {
      var thumb = $("p" + pair.key)
      if (!thumb) return

      var post = pair.value

      var has_tag = post.match_tags.member.bind(post.match_tags)
      post.blacklisted = []
      if(post.id != Post.blacklist_options.exclude)
      {
        Post.blacklists.each(function(b) {
          if (b.require.all(has_tag) && !b.exclude.any(has_tag)) {
            b.hits++
            if (!Post.disabled_blacklists[b.tags]) post.blacklisted.push(b)
          }
        })
      }
      var bld = post.blacklisted.length > 0

      /* The class .javascript-hide hides elements only if JavaScript is enabled, and is
       * applied to all posts by default; we remove the class to show posts.  This prevents
       * posts from being shown briefly during page load before this script is executed,
       * but also doesn't break the page if JavaScript is disabled. */
      count += bld
      if (Post.blacklist_options.replace)
      {
        if(bld)
        {
          thumb.src = "about:blank";

          /* Trying to work around Firefox displaying the old thumb.src briefly before loading
           * the blacklisted thumbnail, even though they're applied at the same time: */
          var f = function(event)
          {
            var img = event.target;
            img.stopObserving("load");
            img.stopObserving("error");
            img.src = "/blacklisted-preview.png";
            img.removeClassName("javascript-hide");
          }
          thumb.observe("load", f)
          thumb.observe("error", f)
        }
        else
        {
          thumb.src = post.preview_url;
          thumb.removeClassName("javascript-hide");
        }
      }
      else
      {
        if(bld)
          thumb.addClassName("javascript-hide");
        else
          thumb.removeClassName("javascript-hide");
      }
    })

    if (Post.countText)
      Post.countText.update(count);

    var notice = $("blacklisted-notice");
    if(notice)
      notice.show(count > 0);

    return count
  },

  // When blacklists are added dynamically and saved, add them here so we don't have to try
  // to edit the cookie in-place.
  current_blacklists: null,
  hide_inactive_blacklists: true,
  disabled_blacklists: {},

  blacklists_update_disabled: function() {
    Post.blacklists.each(function(b) {
      if(!b.a)
        return;
      if(Post.disabled_blacklists[b.tags] || b.hits == 0)
        b.a.addClassName("blacklisted-tags-disabled");
      else
        b.a.removeClassName("blacklisted-tags-disabled");
    });
  },

  // XXX: we lose exclude and replace when we're re-called
  init_blacklisted: function(options) {
    Post.blacklist_options = Object.extend({
      replace: false,
      exclude: null
    }, options);  
    var bl_entries;
    if(Post.current_blacklists)
      bl_entries = Post.current_blacklists;
    else
    {
      bl_entries = Cookie.raw_get("blacklisted_tags").split(/\&/);
      for(var i = 0; i < bl_entries.length; ++i)
        bl_entries[i] = Cookie.unescape(bl_entries[i]);
    }

    Post.blacklists = [];
    bl_entries.each(function(val) {
        var s = val.replace(/(rating:[qes])\w+/, "$1")
        var tags = s.match(/\S+/g)
        if (!tags) return
        var b = { tags: tags, original_tag_string: val, require: [], exclude: [], hits: 0 }
        tags.each(function(tag) {
          if (tag.charAt(0) == '-') b.exclude.push(tag.slice(1))
          else b.require.push(tag)
        })
        Post.blacklists.push(b)
    })
  
    Post.countText = $("blacklist-count")
    if(Post.countText)
      Post.countText.update("");

    Post.apply_blacklists();

    var sidebar = $("blacklisted-sidebar")
    if (sidebar)
      sidebar.show()

    var list = $("blacklisted-list")
    if(list)
    {
      while(list.firstChild)
        list.removeChild(list.firstChild);

      Post.blacklists.sort(function(a, b) {
        if(a.hits == 0 && b.hits > 0) return 1;
        if(a.hits > 0 && b.hits == 0) return -1;
        return a.tags.join(" ").localeCompare(b.tags.join(" "));
      });

      inactive_blacklists_hidden = 0
      Post.blacklists.each(function(b) {
        if (Post.hide_inactive_blacklists && !b.hits)
        {
          ++inactive_blacklists_hidden;
          return;
        }


        var li = list.appendChild(document.createElement("li"))
        li.className = "blacklisted-tags"
        li.style.position = "relative";

        var del = li.appendChild($(document.createElement("a")));
        del.style.position = "absolute";
        del.style.left = "-0.75em";
        del.href = "#";
        del.update("⊘");

        del.observe("click", function(event) {
          /* We need to call run_login_onclick ourself, since this form isn't created with the form helpers. */
          if(!User.run_login_onclick(event)) return false;

          event.stop();

          var tag = b.original_tag_string;
          User.modify_blacklist([], [tag], function(resp) {
            notice("Unblacklisted \"" + tag + "\"");

            Post.current_blacklists = resp.result;
            Post.init_blacklisted();
          });
        });

        li.appendChild(document.createTextNode("» "));

        var a = li.appendChild(document.createElement("a"))
        b.a = a;
        a.href = "#"
        a.className = "no-focus-outline"

        if(!b.hits) {
          a.addClassName("blacklisted-tags-disabled");
        } else {
          $(a).observe("click", function(event) {
            Post.disabled_blacklists[b.tags] = !Post.disabled_blacklists[b.tags]

            Post.apply_blacklists()
            Post.blacklists_update_disabled();
            event.stop()
          });
        }

        var tags = a.appendChild(document.createTextNode(b.tags.join(" ")));
        li.appendChild(document.createTextNode(" "));
        var span = li.appendChild(document.createElement("span"))
        span.className = "post-count"
        if(b.hits > 0)
          span.appendChild(document.createTextNode("(" + b.hits + ")"));
      })

      /* Add the "Show all blacklists" button.  If Post.hide_inactive_blacklists is false, then
       * we've already clicked it and hidden it, so don't recreate it. */
      if(Post.hide_inactive_blacklists && inactive_blacklists_hidden > 0)
      {
        var li = list.appendChild(document.createElement("li"))
        li.className = "no-focus-outline"
        li.id = "blacklisted-tag-show-all"

        var a = li.appendChild(document.createElement("a"))
        a.href = "#"
        a.className = "no-focus-outline"

        $(a).observe("click", function(event) {
          event.stop();
          $("blacklisted-tag-show-all").hide();
          Post.hide_inactive_blacklists = false;
          Post.init_blacklisted();
        });

        var tags = a.appendChild(document.createTextNode("» Show all blacklists"));
        li.appendChild(document.createTextNode(" "));
      }
    }

    Post.blacklists_update_disabled();
  },

  blacklist_add_commit: function()
  {
    var tag = $("add-blacklist").value;
    if(tag == "")
      return;

    $("add-blacklist").value = "";
    User.modify_blacklist(tag, [], function(resp) {
      notice("Blacklisted \"" + tag + "\"");

      Post.current_blacklists = resp.result;
      Post.init_blacklisted();
    });
  },

  last_click_id: null,
  check_avatar_blacklist: function(post_id, id)
  {
    if(id && id == this.last_click_id)
      return true;
    this.last_click_id = id;

    if(!Post.is_blacklisted(post_id))
      return true;

    notice("This post matches one of your blacklists.  Click again to open.");
    return false;
  },

  resize_image: function() {
    var img = $("image");

    if ((img.scale_factor == 1) || (img.scale_factor == null)) {
      img.original_width = img.width;
      img.original_height = img.height;
      var client_width = $("right-col").clientWidth - 15;
      var client_height = $("right-col").clientHeight;

      if (img.width > client_width) {
        var ratio = img.scale_factor = client_width / img.width;
        img.width = img.width * ratio;
        img.height = img.height * ratio;
      }
    } else {
      img.scale_factor = 1;
      img.width = img.original_width;
      img.height = img.original_height;
    }
  
    if (window.Note) {
      for (var i=0; i<window.Note.all.length; ++i) {
        window.Note.all[i].adjustScale()
      }
    }
  },
  
  get_scroll_offset_to_center: function(element)
  {
    var window_size = document.viewport.getDimensions();
    var offset = element.cumulativeOffset();
    var left_spacing = (window_size.width - element.offsetWidth) / 2;
    var top_spacing = (window_size.height - element.offsetHeight) / 2;
    var scroll_x = offset.left - left_spacing;
    var scroll_y = offset.top - top_spacing;
    return [scroll_x, scroll_y];
  },
  center_image: function(img)
  {
    /* Make sure we have enough space to scroll far enough to center the image.  Set a
     * minimum size on the body to give us more space on the right and bottom, and add
     * a padding to the image to give more space on the top and left. */
    if(!img)
      img = $("image");
    if(!img)
      return;

    /* Any existing padding (possibly from a previous call to this function) will be
     * included in cumulativeOffset and throw things off, so clear it. */
    img.setStyle({paddingLeft: 0, paddingTop: 0});

    var target_offset = Post.get_scroll_offset_to_center(img);
    var padding_left = -target_offset[0];
    if(padding_left < 0) padding_left = 0;
    img.setStyle({paddingLeft: padding_left + "px"});

    var padding_top = -target_offset[1];
    if(padding_top < 0) padding_top = 0;
    img.setStyle({paddingTop: padding_top + "px"});

    var window_size = document.viewport.getDimensions();
    var required_width = target_offset[0] + window_size.width;
    var required_height = target_offset[1] + window_size.height;
    $(document.body).setStyle({minWidth: required_width + "px", minHeight: required_height + "px"});

    /* Resizing the body may shift the image to the right, since it's centered in the content.
     * Recalculate offsets with the new cumulativeOffset. */
    var target_offset = Post.get_scroll_offset_to_center(img);
    window.scroll(target_offset[0], target_offset[1]);
  },

  scale_and_fit_image: function(img)
  {
    if(!img)
      img = $("image");
    if(!img)
      return;

    if(img.original_width == null)
    {
      img.original_width = img.width;
      img.original_height = img.height;
    }
    var window_size = document.viewport.getDimensions();
    var client_width = window_size.width;
    var client_height = window_size.height;

    /* Zoom the image to fit the viewport. */
    var ratio = client_width / img.original_width;
    if (img.original_height * ratio > client_height)
      ratio = client_height / img.original_height;
    if(ratio < 1)
    {
      img.width = img.original_width * ratio;
      img.height = img.original_height * ratio;
    }

    this.center_image(img);

    Post.adjust_notes();
  },

  adjust_notes: function() {
    if (!window.Note)
      return;
    for (var i=0; i<window.Note.all.length; ++i) {
      window.Note.all[i].adjustScale()
    }
  },


  highres: function() {
    var img = $("image");
    
    if (img.src == $("highres").href) {
      return;
    }

    // un-resize
    if ((img.scale_factor != null) && (img.scale_factor != 1)) {
      Post.resize_image();
    }

    var f = function() {
      img.stopObserving("load")
      img.stopObserving("error")
      img.height = img.getAttribute("orig_height");
      img.width = img.getAttribute("orig_width");
      img.src = $("highres").href;

      if (window.Note) {
        window.Note.all.invoke("adjustScale")
      }
    }
    
    img.observe("load", f)
    img.observe("error", f)

    // Clear the image before loading the new one, so it doesn't show the old image
    // at the new resolution while the new one loads.  Hide it, so we don't flicker
    // a placeholder frame.
    $('resized_notice').hide();
    img.height = img.width = 0
    img.src = "about:blank"
  },

  set_same_user: function(creator_id)
  {
    var old = $("creator-id-css");
    if(old)
      old.parentNode.removeChild(old);

    var css = ".creator-id-"+ creator_id + " .directlink { background-color: #300 !important; }";
    var style = document.createElement("style");
    style.id = "creator-id-css";
    style.type = "text/css";
    if(style.styleSheet) // IE
      style.styleSheet.cssText = css;
    else
      style.appendChild(document.createTextNode(css));
    document.getElementsByTagName("head")[0].appendChild(style);
  },

  init_post_list: function()
  {
    Post.posts.each(function(p)
    {
      var post_id = p[0]
      var post = p[1]
      var directlink = $("p" + post_id)
      if (!directlink)
        return;
      directlink = directlink.down(".directlink")
      if (!directlink)
        return;
      directlink.observe('mouseover', function(event) { Post.set_same_user(post.creator_id); return false; }, true);
      directlink.observe('mouseout', function(event) { Post.set_same_user(null); return false; }, true);
    });
  },

  init_hover_thumb: function(hover, post_id, thumb, container)
  {
    /* Hover thumbs trigger rendering bugs in IE7. */
    if(Prototype.Browser.IE)
      return;
    hover.observe("mouseover", function(e) { Post.hover_thumb_mouse_over(post_id, hover, thumb, container); });
    hover.observe("mouseout", function(e) { if(e.relatedTarget == thumb) return; Post.hover_thumb_mouse_out(thumb); });
    if(!thumb.hover_init) {
      thumb.hover_init = true;
      thumb.observe("mouseout", function(e) { Post.hover_thumb_mouse_out(thumb); });
    }

  },

  hover_thumb_mouse_over: function(post_id, AlignItem, image, container)
  {
    var post = Post.posts.get(post_id);
    image.hide();

    var offset = AlignItem.cumulativeOffset();
    image.style.width = "auto";
    image.style.height = "auto";
    if(Post.is_blacklisted(post_id))
    {
      image.src = "/preview/blacklisted.png";
    }
    else
    {
      image.src = post.preview_url;
      if(post.status != "deleted")
      {
        image.style.width = post.actual_preview_width + "px";
        image.style.height = post.actual_preview_height + "px";
      }
    }

    var container_top = container.cumulativeOffset().top;
    var container_bottom = container_top + container.getHeight() - 1;

    /* Normally, align to the item we're hovering over.  If the image overflows over
     * the bottom edge of the container, shift it upwards to stay in the container,
     * unless the container's too small and that would put it over the top. */
    var y = offset.top-2; /* -2 for top 2px border */
    if(y + image.getHeight() > container_bottom)
    {
      var bottom_aligned_y = container_bottom - image.getHeight() - 4; /* 4 for top 2px and bottom 2px borders */
      if(bottom_aligned_y >= container_top)
        y = bottom_aligned_y;
    }

    image.style.top = y + "px";
    image.show();
  },

  hover_thumb_mouse_out: function(image)
  {
    image.hide();
  },

  acknowledge_new_deleted_posts: function(post_id) {
    new Ajax.Request("/post/acknowledge_new_deleted_posts.json", {
      onComplete: function(resp) {
        var resp = resp.responseJSON
        
        if (resp.success)
	{
          if ($("posts-deleted-notice"))
            $("posts-deleted-notice").hide()
        } else {
          notice("Error: " + resp.reason)
        }
      }
    })
  },

  hover_info_pin: function(post_id)
  {
    var post = null;
    if(post_id != null)
      post = Post.posts.get(post_id);    
    Post.hover_info_pinned_post = post;
    Post.hover_info_update();
  },

  hover_info_mouseover: function(post_id)
  {
    var post = Post.posts.get(post_id);    
    if(Post.hover_info_hovered_post == post)
      return;
    Post.hover_info_hovered_post = post;
    Post.hover_info_update();
  },

  hover_info_mouseout: function()
  {
    if(Post.hover_info_hovered_post == null)
      return;
    Post.hover_info_hovered_post = null;
    Post.hover_info_update();
  },

  hover_info_hovered_post: null,
  hover_info_displayed_post: null,
  hover_info_shift_held: false,
  hover_info_pinned_post: null, /* pinned by something like the edit menu; shift state and mouseover is ignored */

  hover_info_update: function()
  {
    var post = Post.hover_info_pinned_post;
    if(!post)
    {
      post = Post.hover_info_hovered_post;
      if(!Post.hover_info_shift_held)
        post = null;
    }

    if(Post.hover_info_displayed_post == post)
      return;
    Post.hover_info_displayed_post = post;

    var hover = $("index-hover-info");
    var overlay = $("index-hover-overlay");
    if(!post)
    {
      hover.hide();
      overlay.hide();
      overlay.down("IMG").src = "about:blank";
      return;
    }
    hover.down("#hover-dimensions").innerHTML = post.width + "x" + post.height;
    hover.select("#hover-tags SPAN A").each(function(elem) {
      elem.innerHTML = "";
    });
    post.tags_by_type.each(function(key) {
      var elem = $("hover-tag-" + key[0]);
      var list = []
      key[1].each(function(tag) { list.push(tag); });
      elem.innerHTML = list.join(" ");
    });
    if(post.rating=="s")
      hover.down("#hover-rating").innerHTML = "s";
    else if(post.rating=="q")
      hover.down("#hover-rating").innerHTML = "q";
    else if(post.rating=="e")
      hover.down("#hover-rating").innerHTML = "e";
    hover.down("#hover-post-id").innerHTML = post.id;
    hover.down("#hover-score").innerHTML = post.score;
    if(post.is_shown_in_index)
      hover.down("#hover-not-shown").hide();
    else
      hover.down("#hover-not-shown").show();
    hover.down("#hover-is-parent").show(post.has_children);
    hover.down("#hover-is-child").show(post.parent_id != null);
    hover.down("#hover-is-pending").show(post.status == "pending");
    hover.down("#hover-is-flagged").show(post.status == "flagged");
    var set_text_content = function(element, text)
    {
      (element.innerText || element).textContent = text;
    }

    if(post.status == "flagged")
    {
      hover.down("#hover-flagged-reason").setTextContent(post.flag_detail.reason);
      hover.down("#hover-flagged-by").setTextContent(post.flag_detail.flagged_by);
    }

    hover.down("#hover-file-size").innerHTML = number_to_human_size(post.file_size);
    hover.down("#hover-author").innerHTML = post.author;
    hover.show();

    /* Reset the box to 0x0 before polling the size, so it expands to its maximum size,
     * and read the size. */
    hover.style.left = "0px";
    hover.style.top = "0px";
    var hover_width = hover.scrollWidth;
    var hover_height = hover.scrollHeight;

    var hover_thumb = $("p" + post.id).down("IMG");
    var thumb_offset = hover_thumb.cumulativeOffset();
    var thumb_center_x = thumb_offset[0] + hover_thumb.scrollWidth/2;
    var thumb_top_y = thumb_offset[1];
    var x = thumb_center_x - hover_width/2;
    var y = thumb_top_y - hover_height;

    /* Clamp the X coordinate so the box doesn't fall off the side of the screen.  Don't
     * clamp Y. */
    var client_width = document.viewport.getDimensions()["width"];
    if(x < 0) x = 0;
    if(x + hover_width > client_width) x = client_width - hover_width;
    hover.style.left = x + "px";
    hover.style.top = y + "px";

    overlay.down("A").href = "/post/show/" + post.id;
    overlay.down("IMG").src = post.preview_url;
    
    /* This doesn't always align properly in Firefox if full-page zooming is being
     * used. */
    var x = thumb_center_x - post.actual_preview_width/2;
    var y = thumb_offset[1];
    overlay.style.left = x + "px";
    overlay.style.top = y + "px";
    overlay.show();
  },

  hover_info_shift_down: function()
  {
    if(Post.hover_info_shift_held)
      return;
    Post.hover_info_shift_held = true;
    Post.hover_info_update();
  },

  hover_info_shift_up: function()
  {
    if(!Post.hover_info_shift_held)
      return;
    Post.hover_info_shift_held = false;
    Post.hover_info_update();
  },

  hover_info_init: function()
  {
    document.observe("keydown", function(e) {
      if(e.keyCode != 16) /* shift */
        return;
      Post.hover_info_shift_down();
    });

    document.observe("keyup", function(e) {
      if(e.keyCode != 16) /* shift */
        return;
      Post.hover_info_shift_up();
    });

    document.observe("blur", function(e) { Post.hover_info_shift_up(); });

    var overlay = $("index-hover-overlay");
    Post.posts.each(function(p) {
      var post_id = p[0]
      var post = p[1]

      var span = $("p" + post.id);
      if(span == null)
        return;

      span.down("A").observe("mouseover", function(e) { Post.hover_info_mouseover(post_id); });
      span.down("A").observe("mouseout", function(e) { if(e.relatedTarget && e.relatedTarget.isParentNode(overlay)) return; Post.hover_info_mouseout(); });
    });

    overlay.observe("mouseout", function(e) { Post.hover_info_mouseout(); });
  },

  highlight_posts_with_tag: function(tag)
  {
    Post.posts.each(function(p) {
      var post_id = p[0]
      var post = p[1]
      var thumb = $("p" + post.id);

      if(tag && post.tags.indexOf(tag) != -1)
      {
        thumb.addClassName("highlighted-post");
      } else {
        thumb.removeClassName("highlighted-post");
      }
    });
  },

  reparent_post: function(post_id, old_parent_id, has_grandparent, finished)
  {
    /* If the parent has a parent, this is too complicated to handle automatically. */
    if(has_grandparent)
    {
      alert("The parent post has a parent, so this post can't be automatically reparented.");
      return;
    }

    /*
     * Request a list of child posts.
     * The parent post itself will be returned by parent:.  This is expected; it'll cause us
     * to parent the post to itself, which unparents it from the old parent.
     */
    var change_requests = [];
    new Ajax.Request("/post/index.json", {
      parameters: { tags: "parent:" + old_parent_id },
      
      onComplete: function(resp) {
        var resp = resp.responseJSON
	for(var i = 0; i < resp.length; ++i)
	{
          var post = resp[i];
          if(post.id != post_id && post.parent_id != null)
          {
            alert("The parent post has a parent, so this post can't be automatically reparented.");
            return;
          }
	  change_requests.push({ id: resp[i].id, tags: "parent:" + post_id, old_tags: "" });
        }

	/* We have the list of changes to make in change_requests.  Send a batch
	 * request. */
        if(finished == null)
          finished = function() { document.location.reload() };
	Post.update_batch(change_requests, finished);
      }
    });
  },
  get_url_for_post_in_pool: function(post_id, pool_id)
  {
    return "/post/show/" + post_id + "?pool_id=" + pool_id;
  },
  jump_to_post_in_pool: function(post_id, pool_id)
  {
    if(post_id == null)
    {
      notice("No more posts in this pool");
      return;
    }
    window.location.href = Post.get_url_for_post_in_pool(post_id, pool_id);
  }
}
