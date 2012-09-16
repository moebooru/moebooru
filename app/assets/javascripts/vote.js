(function($) {
  var Vote = function () {
    this.api = {
      set: '/post/vote.json'
    };
    this.v = {
      fav: 3,
      great: 2,
      good: 1,
      remove: 0
    };
    this.label = [
      t('vote.remove'), t('vote.good'), t('vote.great'), t('vote.fav')
    ];
  };

  Vote.prototype = {
    registerVotes: function (votes) {
      this.posts = votes;
    },

    registerUserVotes: function (votes) {
      this.votes = votes;
    },

    getScore: function () {
      this.current_post = Moebooru.get('post').current;
      try {
        return this.current_post.score;
      } catch (error) {}
      return null;
    },

    getVote: function () {
      return this.posts[this.current_post.id] || 0;
    },

    set: function (vote) {
      if (vote > this.v.fav) return false;
      notice(t('voting') + '...');
      Moebooru.request(this.api.set, {id: this.current_post.id, score: vote});
      return false;
    },

    updateWidget: function () {
      var score = this.getScore(),
          vote = this.getVote();
      for (var i = 1; i <= this.v.fav; i++) {
        var star = $('.star-'+i);
        if (i <= vote) {
          star.removeClass('star-set-after');
          star.addClass('star-set-upto');
        } else {
          star.removeClass('star-set-upto');
          star.addClass('star-set-after');
        }
      }
      if (vote === this.v.fav) {
        $('#add-to-favs').css('display', 'none');
        $('#remove-from-favs').css('display', 'list-item');
      } else {
        $('#add-to-favs').css('display', 'list-item');
        $('#remove-from-favs').css('display', 'none');
      }
      $('#post-score-'+this.current_post.id).html(score);
      try {
        $('#favorited-by').html(Favorite.link_to_users(this.votes[this.v.fav]));
      } catch (error) {}
      return false;
    }
  };

  $(function() {
    var container = $('#stats'),
        star = $('.star-off'),
        vote = new Vote();

    if (container.length === 0) return false;

    function get_score(o) {
      var match = o.match(/star\-(\d)/);
      try {
        if (match.length === 2) {
          return parseInt(match[1]);
        }
      } catch (error) {}
      return -1;
    }

    Moe.on('vote:add', function (e, data) {
      vote.registerVotes(data);
    });

    Moe.on('vote:add_user_list', function (e, data) {
      vote.registerUserVotes(data);
    });

    Moe.on(vote.api.set+':ready', function (e, data) {
      notice(t('vote_saved'));
      Moebooru.addData(data);
      vote.updateWidget();
    });

    Moe.on('vote:update_widget', function () {
      vote.updateWidget();
    });

    $('#add-to-favs').on('click', function () {
      return vote.set(vote.v.fav);
    });

    $('#remove-from-favs').on('click', function () {
      return vote.set(vote.v.great);
    });

    $('.vote-up').on('click', function () {
      var current_score = vote.getVote();
      if (current_score === vote.v.fav) return false;
      return vote.set(current_score + 1);
    });

    star.on('click', function () {
      var score = get_score(this.className);
      return vote.set(score);
    });

    star.on('mouseover', function () {
      var score = get_score(this.className);
      for (var i = 1; i <= vote.v.fav; i++) {
        var star = $('.star-'+i);
        if (i <= score) {
          star.removeClass('star-hovered-after');
          star.addClass('star-hovered-upto');
        } else {
          star.removeClass('star-hovered-upto');
          star.addClass('star-hovered-after');
        }
        if (i != score) {
          star.removeClass('star-hovered');
          star.addClass('star-unhovered');
        } else {
          star.removeClass('star-unhovered');
          star.removeClass('star-hovered');
        }
      }
      $('.vote-desc').html(vote.label[score]);
      return false;
    });

    star.on('mouseout', function () {
      for (var i = 1; i <= vote.v.fav; i++) {
        var star = $('.star-'+i);
        star.removeClass('star-hovered');
        star.removeClass('star-unhovered');
        star.removeClass('star-hovered-after');
        star.removeClass('star-hovered-upto');
      }
      $('.vote-desc').html('');
      return false;
    });

    $(document).on('keydown', function (e) {
      if (e.target.nodeName !== 'BODY') return;
      switch (e.which) {
        case 192: return vote.set(vote.v.remove); // `
        case  49: return vote.set(vote.v.good);   // 1
        case  50: return vote.set(vote.v.great);  // 2
        case  51: return vote.set(vote.v.fav);    // 3
        default:  return true;
      }
    });
  });
})(jQuery);
