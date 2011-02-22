PostModeMenu = {
  mode: "view",

  init: function(pool_id) {
    try {	/* This part doesn't work on IE7; for now, let's allow execution to continue so at least some initialization is run */

    /* If pool_id isn't null, it's the pool that we're currently searching for. */
    this.pool_id = pool_id;

    var color_element = $("mode-box")
    this.original_style = { border: color_element.getStyle("border") }
    
    if (Cookie.get("mode") == "") {
      Cookie.put("mode", "view")
      $("mode").value = "view"
    } else {
      $("mode").value = Cookie.get("mode")
    }

    } catch (e) {}
    
    this.vote_score = Cookie.get("vote")
    if (this.vote_score == "") {
      this.vote_score = 1
      Cookie.put("vote", this.vote_score)
    } else {
      this.vote_score == +this.vote_score
    }
  
    Post.posts.each(function(p) {
      var post_id = p[0]
      var post = p[1]

      var span = $("p" + post.id);
      if(span == null)
        return;

      /* Use post_id here, not post, since the post object can be replaced later after updates. */
      span.down("A").observe("click", function(e) { PostModeMenu.click(e, post_id); });
      span.down("A").observe("mousedown", function(e) { PostModeMenu.post_mousedown(e, post_id); });
      span.down("A").observe("mouseover", function(e) { PostModeMenu.post_mouseover(e, post_id); });
      span.down("A").observe("mouseout", function(e) { PostModeMenu.post_mouseout(e, post_id); });
      span.down("A").observe("mouseup", function(e) { PostModeMenu.post_mouseup(e, post_id); });
    });

    document.observe("mouseup", function(e) { PostModeMenu.post_mouseup(e, null); });
    Event.observe(window, "pagehide", function(e) { PostModeMenu.post_end_drag(); });

    this.change()  
  },

  set_vote: function(score) {
    this.vote_score = score
    Cookie.put("vote", this.vote_score)
    Post.update_vote_widget('vote-menu', this.vote_score);
  },

  get_style_for_mode: function(s)
  {
    if (s == "view") {
      return {background: ""};
    } else if (s == "edit") {
      return {background: "#3A3"}
    } else if (s == "rating-q") {
      return {background: "#AAA"}
    } else if (s == "rating-s") {
      return {background: "#6F6"}
    } else if (s == "rating-e") {
      return {background: "#F66"}
    } else if (s == "vote") {
      return {background: "#FAA"}
    } else if (s == "lock-rating") {
      return {background: "#AA3"}
    } else if (s == "lock-note") {
      return {background: "#3AA"}
    } else if (s == "approve") {
      return {background: "#26A"}
    } else if (s == "flag") {
      return {background: "#F66"}
    } else if (s == "add-to-pool") {
      return {background: "#26A"}
    } else if (s == "apply-tag-script") {
      return {background: "#A3A"}
    } else if (s == "reparent-quick") {
      return {background: "#CCA"}
    } else if (s == "remove-from-pool") {
      return {background: "#CCA"}
    } else if (s == 'reparent') {
      return {background: "#0C0"}
    } else if (s == 'dupe') {
      return {background: "#0C0"}
    } else {
      return {background: "#AFA"}
    }
  },

  change: function() {
    if(!$("mode"))
      return;
    var s = $F("mode")
    Cookie.put("mode", s, 7)

    PostModeMenu.mode = s

    if (s.value != "edit") {
      $("quick-edit").hide()
    }
    if (s.value != "apply-tag-script") {
      $("edit-tag-script").hide()
      Post.reset_tag_script_applied()
    }

    if (s == "vote") {
      Post.update_vote_widget('vote-menu', this.vote_score);
      $("vote-score").show()
    } else if (s == "apply-tag-script") {
      $("edit-tag-script").show()
      $("edit-tag-script").focus()
    }
  },

  click: function(event, post_id) {
    var s = $("mode")
    if(!s)
      return;

    if (s.value == "view") {
      return true
    }

    if (s.value == "edit") {
      post_quick_edit.show(post_id);
    } else if (s.value == 'vote') {
      Post.vote(post_id, this.vote_score)
    } else if (s.value == 'rating-q') {
      Post.update_batch([{id: post_id, rating: "questionable"}]);
    } else if (s.value == 'rating-s') {
      Post.update_batch([{id: post_id, rating: "safe"}]);
    } else if (s.value == 'rating-e') {
      Post.update_batch([{id: post_id, rating: "explicit"}]);
    } else if (s.value == 'reparent') {
      if(post_id == id)
       return false;
      TagScript.run(post_id, "parent:" + id)
    } else if (s.value == 'dupe') {
      if(post_id == id)
       return false;
      TagScript.run(post_id, "duplicate parent:" + id)
    } else if (s.value == 'lock-rating') {
      Post.update_batch([{id: post_id, is_rating_locked: "1"}]);
    } else if (s.value == 'lock-note') {
      Post.update_batch([{id: post_id, is_note_locked: "1"}]);
    } else if (s.value == 'flag') {
      Post.flag(post_id)
    } else if (s.value == "approve") {
      Post.approve(post_id)
    } else if (s.value == 'add-to-pool') {
      Pool.add_post(post_id, 0)
    } else if (s.value == "remove-from-pool") {
      Pool.remove_post(post_id, PostModeMenu.pool_id);
    }

    event.stopPropagation();
    event.preventDefault();
  },

  dragging_from_post: null,
  dragging_active: false,
  dragging_list: null,
  dragging_hash: null,

  post_add_to_hovered_list: function(post_id)
  {
    var element = element = $$("#p" + post_id + " > .directlink");
    if(element.length > 0)
    {
      element[0].addClassName("tag-script-applied");
      Post.applied_list.push(element[0]);
    }

    if(!PostModeMenu.dragging_hash.get(post_id))
    {
      PostModeMenu.dragging_hash.set(post_id, true);
      PostModeMenu.dragging_list.push(post_id);
    }
  },

  post_mousedown: function(event, post_id)
  {
    if(event.button != 0)
      return;

    if(PostModeMenu.mode == "reparent-quick")
    {
      PostModeMenu.dragging_from_post = post_id;
      PostModeMenu.post_begin_drag();
    }
    else if(PostModeMenu.mode == "apply-tag-script")
    {
      Post.reset_tag_script_applied();
      PostModeMenu.dragging_from_post = post_id;
      PostModeMenu.dragging_list = new Array;
      PostModeMenu.dragging_hash = new Hash;
      PostModeMenu.post_add_to_hovered_list(post_id);
    }
    else
      return;

    /* Prevent the mousedown from being processed; this keeps it from turning into
     * a real drag action, which will suppress our mouseover/mouseout messages.  We
     * only do this when the tag script is enabled, so we don't mess with regular
     * clicks. */
    event.preventDefault();
    event.stopPropagation();
  },

  post_begin_drag: function(type)
  {
    document.body.addClassName("dragging-to-post");
  },

  post_end_drag: function()
  {
    document.body.removeClassName("dragging-to-post");
    PostModeMenu.dragging_from_post = null;
  },

  post_mouseup: function(event, post_id)
  {
    if(event.button != 0)
      return;
    if(!PostModeMenu.dragging_from_post)
      return;

    if(PostModeMenu.mode == "reparent-quick")
    {
      if(post_id)
      {
        notice("Updating post");
        Post.update_batch([{ id: PostModeMenu.dragging_from_post, parent_id: post_id}]);
      }

      PostModeMenu.post_end_drag();
      return;
    }
    else if(PostModeMenu.mode == "apply-tag-script")
    {
      if(post_id)
        return;

      /* We clicked or dragged some posts to apply a tag script; process it. */
      var tag_script = TagScript.TagEditArea.value;
      TagScript.run(PostModeMenu.dragging_list, tag_script);

      PostModeMenu.dragging_from_post = null;
      PostModeMenu.dragging_active = false;
      PostModeMenu.dragging_list = null;
      PostModeMenu.dragging_hash = null;
    }
  },

  post_mouseover: function(event, post_id)
  {
    var post = $("p" + post_id);
    var style = PostModeMenu.get_style_for_mode(PostModeMenu.mode)
    post.down("span").setStyle(style)

    if(PostModeMenu.mode != "apply-tag-script")
      return;
    
    if(!PostModeMenu.dragging_from_post)
      return;

    if(post_id != PostModeMenu.dragging_from_post)
      PostModeMenu.dragging_active = true;

    PostModeMenu.post_add_to_hovered_list(post_id);
  },

  post_mouseout: function(event, post_id)
  {
    var post = $("p" + post_id);
    post.down("span").setStyle({background: ""});
  },

  apply_tag_script_to_all_posts: function()
  {
    var tag_script = TagScript.TagEditArea.value;
    var post_ids = Post.posts.inject([], function(list, pair) {
      list.push(pair[0]);
      return list;
    });

    TagScript.run(post_ids, tag_script);
  }
}

TagScript = {
  TagEditArea: null,

  load: function() {
    this.TagEditArea.value = Cookie.get("tag-script")
  },
  save: function() {
    Cookie.put("tag-script", this.TagEditArea.value)
  },

  init: function(element, x) {
    this.TagEditArea = element

    TagScript.load()

    this.TagEditArea.observe("change", function(e) { TagScript.save() })
    this.TagEditArea.observe("focus", function(e) { Post.reset_tag_script_applied() })

    /* This mostly keeps the tag script field in sync between windows, but it
     * doesn't work in Opera, which sends focus events before blur events. */
    document.observe("blur", function(e) { TagScript.save() })
    document.observe("focus", function(e) { TagScript.load() })
  },

  parse: function(script) {
    return script.match(/\[.+?\]|\S+/g)
  },

  test: function(tags, predicate) {
    var split_pred = predicate.match(/\S+/g)
    var is_true = true

    split_pred.each(function(x) {
      if (x[0] == "-") {
        if (tags.include(x.substr(1, 100))) {
          is_true = false
          throw $break
        }
      } else {
        if (!tags.include(x)) {
          is_true = false
          throw $break
        }
      }
    })

    return is_true
  },

  process: function(tags, command) {
    if (command.match(/^\[if/)) {
      var match = command.match(/\[if\s+(.+?)\s*,\s*(.+?)\]/)
      if (TagScript.test(tags, match[1])) {
        return TagScript.process(tags, match[2])
      } else {
        return tags
      }
    } else if (command == "[reset]") {
      return []
    } else if (command[0] == "-" && command.indexOf("-pool:") != 0) {
      return tags.reject(function(x) {return x == command.substr(1, 100)})
    } else {
      tags.push(command)
      return tags
    }
  },

  run: function(post_ids, tag_script, finished) {
    if(!Object.isArray(post_ids))
      post_ids = $A([post_ids]);

    var commands = TagScript.parse(tag_script) || []

    var posts = new Array;
    post_ids.each(function(post_id) {
      var post = Post.posts.get(post_id)
      var old_tags = post.tags.join(" ")

      commands.each(function(x) {
        post.tags = TagScript.process(post.tags, x)
      })

      posts.push({
        id: post_id,
        old_tags: old_tags,
        tags: post.tags.join(" ")
      });
    });

    notice("Updating " + posts.length + (post_ids.length == 1? " post": " posts") );
    Post.update_batch(posts, finished);
  }
}

function PostQuickEdit(container)
{
  this.container = container;
  this.submit_event = this.submit_event.bindAsEventListener(this);

  this.container.down("form").observe("submit", this.submit_event);
  this.container.down(".cancel").observe("click", function(e) {
    e.preventDefault();
    this.hide();
  }.bindAsEventListener(this));
  this.container.down("#post_tags").observe("keydown", function(e) {
    if(e.keyCode == Event.KEY_ESC)
    {
      e.stop();
      this.hide();
      return;
    }

    if(e.keyCode != Event.KEY_RETURN)
      return;
    this.submit_event(e);
  }.bindAsEventListener(this));
}

PostQuickEdit.prototype.show = function(post_id)
{
  Post.hover_info_pin(post_id);

  var post = Post.posts.get(post_id);
  this.post_id = post_id;
  this.old_tags = post.tags.join(" ");

  this.container.down("#post_tags").value = post.tags.join(" ") + " rating:" + post.rating.substr(0, 1) + " ";
  this.container.show();
  this.container.down("#post_tags").focus();
}

PostQuickEdit.prototype.hide = function()
{
  this.container.hide();
  Post.hover_info_pin(null);
}

PostQuickEdit.prototype.submit_event = function(e)
{
  e.stop();
  this.hide();

  Post.update_batch([{id: this.post_id, tags: this.container.down("#post_tags").value, old_tags: this.old_tags}], function() {
    notice("Post updated");
    this.hide();
  }.bind(this));
}

