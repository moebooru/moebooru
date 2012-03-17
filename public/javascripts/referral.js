ReferralBanner = function(ref)
{
  /* Stop if > privileged: */
  if(User.get_current_user_level() > 30)
  {
    this.container = null;
    return;
  }

  this.container = ref;
  if(!ref)
    return;

  this.container.down(".close-button").on("click", function(e) {
    e.stop();
    this.container.removeClassName("shown");
  }.bind(this));
}

ReferralBanner.prototype.show_referral = function()
{
  if(!this.container)
    return;

  this.container.show();

  /* If we don't defer after removing display: none, the -webkit-transition won't transition
   * from the correct position. */
  (function() {
    this.container.addClassName("shown");
  }).bind(this).defer();
}


ReferralBanner.prototype.increment_view_count = function()
{
  var view_count = Cookie.get_int("viewed");
  ++view_count;

  Cookie.put("viewed", view_count);
  return view_count;
}

ReferralBanner.prototype.increment_views_and_check_referral = function()
{
  var delay_between_referral_reset = 60*60*24;
  var view_count_before_referral = 9999;

  var view_count = this.increment_view_count();

  /* sref is the last time we showed the referral.  As long as it's set, we won't show
   * it again. */
  var referral_last_shown = Cookie.get_int("sref");
  var now = new Date().getTime() / 1000;

  /* If the last time the referral was shown was a long time ago, clear everything and start over.
   * Once we clear this, vref is set and we'll start counting views from there.
   *
   * Also clear the timer if it's in the future; this can happen if the clock was adjusted. */
  if(referral_last_shown && (referral_last_shown > now || now - referral_last_shown >= delay_between_referral_reset))
  {
    Cookie.put("sref", 0);
    referral_last_shown = 0;
    Cookie.put("vref", view_count - 1);
  }

  if(referral_last_shown)
    return;

  var view_count_start = Cookie.get_int("vref");
  if(view_count >= view_count_start && view_count - view_count_start < view_count_before_referral)
    return;

  Cookie.put("sref", now);
  this.show_referral();
}

