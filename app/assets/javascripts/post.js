(function ($) {
  var Post = function () {
    this.posts = {};
  };

  Post.prototype = {
    registerPosts: function (posts) {
      var th = this;
      if (posts.length == 1) {
        this.current = posts[0];
      }
      posts.forEach(function(p, idx, arr) {
        p.tags = p.tags.match(/\S+/g) || [];
        p.metatags = p.tags.clone();
        p.metatags.push("rating:" + p.rating[0]);
        p.metatags.push("status:" + p.status);
        th.posts[p.id] = p;
      });
      return false;
    },

    get: function (post_id) {
      return this.posts[post_id];
    }
  };

  $(function() {
    var post = new Post(),
      inLargerVersion = false;

    Moe.on('post:add', function (e, data) {
      post.registerPosts(data);
    });

    $('.highres-show').on('click', function () {
      var img = $('#image'),
        w = img.attr('large_width'),
        h = img.attr('large_height');
      if (inLargerVersion) { return false; }
      inLargerVersion = true;
      $('#resized_notice').hide();
      img.hide();
      img.attr('src', '');
      img.attr('width', w);
      img.attr('height', h);
      img.attr('src', this.href);
      img.show();
      window.Note.all.invoke('adjustScale');
      return false;
    });

    $('#post_tags').on('keydown', function (e) {
      if (e.which == 13) {
        e.preventDefault();
        $('#edit-form').submit();
      }
    });
  });
})(jQuery);
