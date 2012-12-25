(function($) {
  Menu2 = {
    forum_status_update: function() {
      var anynew = ($.cookie('forum_updated') == '1');
      var forum_posts = $.cookie('current_forum_posts');
      if (!forum_posts) {
        forum_posts = {};
      } else {
        forum_posts = forum_posts.evalJSON(true);
      };
      if (anynew) {
        $('forum-link').addClass('bolded');
        $('forum-mark-all-read').show();
      } else {
        $('forum-link').removeClass('bolded');
        $('forum-mark-all-read').hide();
      };
      for (var i = 0; i < forum_posts.length; ++i) {
        var fp = forum_posts[i]
        var fp_link = $('menu-forum-post-' + fp[1]);
        if (fp_link) {
          if(fp[2]) {
            fp_link.addClass('bolded');
          } else {
            fp_link.removeClass('bolded');
          };
        };
      };
    }
  };
}) (jQuery);
