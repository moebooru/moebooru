VoteWidget = function(container)
{
  if(!container.hasClassName("vote-container"))
    container = container.up(".vote-container");
  if(!container)
    throw "Couldn't find .vote-container element";

  this.container = container;
  this.post_id = null;

  if(container.down(".remove-vote"))
  {
    container.down(".remove-vote").on("mouseover", function(e) { this.vote_mouse_over("Remove vote", 0); }.bindAsEventListener(this));
    container.down(".remove-vote").on("mouseout", function(e) { this.vote_mouse_out("Remove vote", 0); }.bindAsEventListener(this));
    container.down(".remove-vote").on("click", function(e) { e.stop(); this.vote(0); }.bindAsEventListener(this));
  }

  if(container.down(".vote-up-anonymous"))
    container.down(".vote-up-anonymous").on("click", function(e) { e.stop(); this.vote(+1); }.bindAsEventListener(this));

  if(container.down(".vote-up"))
    container.down(".vote-up").on("click", function(e) { e.stop(); this.vote_up(); }.bindAsEventListener(this));

  var vote_descs =
  {
    "0": "Neutral",
    "1": "Good",
    "2": "Great",
    "3": "Favorite"
  };

  container.select(".star").each(function(s) {
    var vote_match = s.className.match(/.* star-(\d+)/);
    if(!vote_match)
      return;
    var vote = parseInt(vote_match[1]);

    var desc = vote_descs[vote];
    s.on("click", function(e) { e.stop(); this.vote(vote); }.bindAsEventListener(this));
    s.on("mouseover", function(e) { this.vote_mouse_over(desc, vote); }.bindAsEventListener(this));
    s.on("mouseout", function(e) { this.vote_mouse_out(desc, vote); }.bindAsEventListener(this));
  }.bind(this));

  document.on("posts:update", this.post_update_event.bindAsEventListener(this));
}

/* One or more posts have been updated; see if the vote we should be displaying
 * has changed. */
VoteWidget.prototype.post_update_event = function(e)
{
  var post_id = this.post_id;
  if(e.memo.post_ids.get(post_id) == null)
    return;

  var new_vote = Post.votes.get(post_id);
  this.vote_set_stars(new_vote);

  if(this.container.down("#post-score-" + post_id))
  {
    var post = Post.posts.get(post_id);
    if(post)
      this.container.down("#post-score-" + post_id).update(post.score)
  }

  if(this.container.down("#favorited-by")) {
    this.container.down("#favorited-by").update(Favorite.link_to_users(e.memo.resp.voted_by["3"]))
  }
}

VoteWidget.prototype.set_post_id = function(post_id)
{
  var vote = Post.votes.get(post_id) || 0;
  this.post_id = post_id;
  this.vote_set_stars(vote);
}

VoteWidget.prototype.init_hotkeys = function()
{
  OnKey(192, null, function(e) { this.vote(+0); return true; }.bindAsEventListener(this)); // `
  OnKey(49, null, function(e) { this.vote(+1); return true; }.bindAsEventListener(this));
  OnKey(50, null, function(e) { this.vote(+2); return true; }.bindAsEventListener(this));
  OnKey(51, null, function(e) { this.vote(+3); return true; }.bindAsEventListener(this));
}

VoteWidget.prototype.vote_up = function()
{
  var current_vote = Post.votes.get(this.post_id);
  return this.vote(current_vote + 1);
}

VoteWidget.prototype.vote = function(score)
{
  return Post.vote(this.post_id, score);
}

VoteWidget.prototype.vote_mouse_over = function(desc, vote)
{
  this.vote_set_stars(vote);
  this.container.down(".vote-desc").update(desc);
}

VoteWidget.prototype.vote_mouse_out = function(desc, vote)
{
  var original_vote = Post.votes.get(this.post_id);
  this.vote_set_stars(original_vote);
  this.container.down(".vote-desc").update();
}

VoteWidget.prototype.vote_set_stars = function(vote)
{
  var stars = this.container.down(".stars").select("a")
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
}

