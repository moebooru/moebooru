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
      [{ id: old_post_id, tags: "-pool:" + pool_id },
       { id: new_post_id, tags: "pool:" + pool_id + ":" + sequence }],
      function() {
        notice("Pool post transferred to parent")
        if($("p" + old_post_id))
          $("p" + old_post_id).remove()
        if($("pool" + pool_id))
          $("pool" + pool_id).remove()
      }
    );
  }
}
