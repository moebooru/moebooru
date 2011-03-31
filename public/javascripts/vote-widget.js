VoteWidget = function(container)
{
  this.container = container;
  this.post_id = null;
  this.displayed_hover = -1;
  this.displayed_set = -1;

  if(container.down(".vote-up"))
    container.down(".vote-up").on("click", function(e) { e.stop(); this.vote_up(); }.bindAsEventListener(this));

  var vote_descs =
  {
    "0": "Remove vote",
    "1": "Good",
    "2": "Great",
    "3": "Favorite"
  };

  for(var stars = 0; stars <= 3; ++stars)
  {
    var s = this.container.down(".star-" + stars);
    if(!s)
      continue;
    s.star = stars;
    s.desc = vote_descs[stars];
  }

  this.container.on("click", ".star", function(e) { e.stop(); this.activate_item(e.target); }.bindAsEventListener(this));
  this.container.on("mouseover", ".star", function(e) { this.set_mouseover(e.target); }.bindAsEventListener(this));
  this.container.on("mouseout", ".star", function(e) { this.set_mouseover(e.relatedTarget); }.bindAsEventListener(this));

  document.on("posts:update", this.post_update_event.bindAsEventListener(this));
}

VoteWidget.prototype.get_star_element = function(element)
{
  if(!element)
    return null;
  if(element.hasClassName("star"))
    return element;
  else
    return element.up(".star");
}

VoteWidget.prototype.set_mouseover = function(element)
{
  if(element)
    element = this.get_star_element(element);
  if(!element)
  {
    this.set_stars(null);
    var text = this.container.down(".vote-desc");
    if(text)
      text.update();
    return false;
  }
  else
  {
    this.set_stars(element.star);
    var text = this.container.down(".vote-desc");
    if(text)
      text.update(element.desc);
    return true;
  }
}

VoteWidget.prototype.activate_item = function(element)
{
  element = this.get_star_element(element);
  if(!element)
    return null;
  this.vote(element.star);
  return element.star;
}


/* One or more posts have been updated; see if the vote we should be displaying
 * has changed. */
VoteWidget.prototype.post_update_event = function(e)
{
  var post_id = this.post_id;
  if(e.memo.post_ids.get(post_id) == null)
    return;

  this.set_stars(this.displayed_hover);

  if(this.container.down("#post-score-" + post_id))
  {
    var post = Post.posts.get(post_id);
    if(post)
      this.container.down("#post-score-" + post_id).update(post.score)
  }

  if(e.memo.resp.voted_by && this.container.down("#favorited-by")) {
    this.container.down("#favorited-by").update(Favorite.link_to_users(e.memo.resp.voted_by["3"]))
  }
}

VoteWidget.prototype.set_post_id = function(post_id)
{
  var vote = Post.votes.get(post_id) || 0;
  this.post_id = post_id;
  this.set_stars(null);
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

var array_select = function(list, y, n, val)
{
  if(val)
    list.push(y);
  else
    list.push(n);
}

VoteWidget.prototype.set_stars = function(hovered_vote)
{
  var set_vote = Post.votes.get(this.post_id);

  if(this.displayed_hover == hovered_vote && this.displayed_set == set_vote)
    return;
  this.displayed_hover = hovered_vote;
  this.displayed_set = set_vote;

  for(var star_vote = 0; star_vote <= 3; ++star_vote)
  {
    var star = this.container.down(".star-" + star_vote);
    if(!star)
      continue;
    var className = star.className;
    className = className.replace(/(star-hovered|star-unhovered|star-hovered-upto|star-hovered-after|star-set|star-unset|star-set-upto|star-set-after)(\s+|$)/g, " ");
    className = className.strip();
    var classes = className.split(" ");

    if(hovered_vote != null)
    {
      array_select(classes, "star-hovered", "star-unhovered", hovered_vote == star_vote);
      array_select(classes, "star-hovered-upto", "star-hovered-after", hovered_vote >= star_vote);
    }
    array_select(classes, "star-set", "star-unset", set_vote != null && set_vote == star_vote);
    array_select(classes, "star-set-upto", "star-set-after", set_vote != null && set_vote >= star_vote);

    star.className = classes.join(" ");
  }
}

