var Moebooru = {};
var Moe = jQuery(Moebooru);

Moebooru.addData = function (data) {
  if (data.posts)
    Moe.trigger("post:add", data.posts);
  if (data.tags)
    Moe.trigger("tag:add", data.tags);
  if (data.votes)
    Moe.trigger("vote:add", data.votes);
  if (data.pools)
    Moe.trigger("pool:add", data.pools);
  if(data.pool_posts)
    Moe.trigger("pool:add_post", {
      pool_posts: data.pool_posts,
      posts: data.posts
    });
};
