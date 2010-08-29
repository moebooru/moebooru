Pool = {
  add_post: function(post_id, pool_id) {
    notice("Adding to pool...")

    new Ajax.Request("/pool/add_post.json", {
      parameters: {
        "post_id": post_id,
        "pool_id": pool_id
      },
      onComplete: function(resp) {
        var resp = resp.responseJSON
      
        if (resp.success) {
          notice("Post added to pool")
        } else {
          notice("Error: " + resp.reason)        
        }
      }
    })
  },

  remove_post: function(post_id, pool_id) {
    new Ajax.Request('/pool/remove_post.json', {
      parameters: {
        "post_id": post_id,
        "pool_id": pool_id
      },
      onComplete: function(resp) {
        var resp = resp.responseJSON
        
        if (resp.success) {
          notice("Post removed from pool")
          if($("p" + post_id))
            $("p" + post_id).remove()            
          if($("pool" + pool_id))
            $("pool" + pool_id).remove()            
        } else {
          notice("Error: " + resp.reason)
        }          
      }
    })
  },

  transfer_post: function(old_post_id, new_post_id, pool_id, sequence)
  {
    Post.update_batch(
      [{ id: old_post_id, tags: "-pool:" + pool_id, old_tags: "" },
       { id: new_post_id, tags: "pool:" + pool_id + ":" + sequence, old_tags: "" }],
      function() {
        notice("Pool post transferred to parent")

	/* We might be on the parent or child, which will do different things to
	 * the pool status display.  Just reload the page. */
	document.location.reload();
      }
    );
  },

  detach_post: function(post_id, pool_id, is_parent)
  {
    Post.update_batch(
      [{ id: post_id, tags: "-pool:" + pool_id, old_tags: "" }],
      function() {
        notice("Post detached")
        if(is_parent) {
          var elem = $("pool-detach-" + pool_id + "-" + post_id);
          if(elem)
            elem.remove()
        } else {
          if($("pool" + pool_id))
            $("pool" + pool_id).remove()
        }
      }
    );
  },

  /* This matches PoolPost.pretty_sequence. */
  post_pretty_sequence: function(sequence)
  {
    if(sequence.match(/^[0-9]+.*/))
      return "#" + sequence;
    else
      return "\"" + sequence + "\"";
  },

  change_sequence: function(post_id, pool_id, old_sequence)
  {
    new_sequence = prompt("Please enter the new page number:", old_sequence);
    if(new_sequence == null)
      return;
    if(new_sequence.indexOf(" ") != -1)
    {
      notice("Invalid page number");
      return;
    }

    Post.update_batch(
      [{ id: post_id, tags: "pool:" + pool_id + ":" + new_sequence, old_tags: "" }],
      function() {
        notice("Post updated")
        var elem = $("pool-seq-" + pool_id);
        if(!Object.isUndefined(elem.innerText))
          elem.innerText = Pool.post_pretty_sequence(new_sequence);
        else
          elem.textContent = Pool.post_pretty_sequence(new_sequence);
      }
    );
  }
}
