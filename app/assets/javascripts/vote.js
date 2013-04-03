(function ($, t) {
  var REMOVE = 0, GOOD = 1, GREAT = 2, FAVORITE = 3;

  this.Vote = function (container, id) {
    var nodes = container.find('*');
    this.desc = nodes.filter('.vote-desc');
    this.stars = nodes.filter('.star-off');
    this.post_score = nodes.filter('#post-score-'+id+', .post-score');
    this.vote_up = nodes.filter('.vote-up');
    this.post_id = id;
    this.label = [t('.remove'), t('.good'), t('.great'), t('.fav')];
    this.setupEvents();
    this.data = { score: null, vote: null };
  };

  this.Vote.prototype = {
    set: function (vote) {
      var th = this;
      notice(t('.voting'));
      $.ajax({
        url: Moebooru.path('/post/vote.json'),
        data: {id: this.post_id, score: vote},
        dataType: 'json',
        type: 'post',
        statusCode: {
          403: function () { notice(t('js.error')+': '+t('js.denied')); }
        }
      }).done(function (data) {
        th.updateWidget(vote, data.posts[0].score);
        $('#favorited-by').html(Favorite.link_to_users(data.voted_by[FAVORITE])); 
        notice(t('.saved'));
      });
      return false;
    },

    setupEvents: function () {
      var th = this, stars = this.stars;

      function get_score(o) {
        var match = o.match(/star\-(\d)/);
        try {
          if (match.length === 2) {
            return parseInt(match[1]);
          }
        } catch (error) {}
        return -1;
      }

      stars.on('click', function () {
        var score = get_score(this.className);
        return th.set(score);
      });

      stars.on('mouseover', function () {
        var score = get_score(this.className);
        for (var i = 1; i <= FAVORITE; i++) {
          var star = $(stars[i]);
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
        th.desc.text(th.label[score]);
        return false;
      });

      stars.on('mouseout', function () {
        for (var i = 1; i <= FAVORITE; i++) {
          var star = $(stars[i]);
          star.removeClass('star-hovered');
          star.removeClass('star-unhovered');
          star.removeClass('star-hovered-after');
          star.removeClass('star-hovered-upto');
        }
        th.desc.text('');
        return false;
      });

      this.vote_up.on('click', function () {
        if (th.vote < FAVORITE) return th.set(th.vote + 1);
        return false;
      });

      $('#add-to-favs > a').on('click', function () {
        return th.set(FAVORITE);
      });

      $('#remove-from-favs > a').on('click', function () {
        return th.set(GREAT);
      })
    },

    updateWidget: function (vote, score) {
      var add = $('#add-to-favs'),
          rm = $('#remove-from-favs');
      this.vote = vote || 0;
      this.data.score = score;
      this.data.vote = vote;
      for (var i = 1; i <= FAVORITE; i++) {
        var star = $(this.stars[i]);
        if (i <= vote) {
          star.removeClass('star-set-after');
          star.addClass('star-set-upto');
        } else {
          star.removeClass('star-set-upto');
          star.addClass('star-set-after');
        }
      }
      if (vote === FAVORITE) {
        add.hide();
        rm.show();
      } else {
        add.show();
        rm.hide();
      }
      this.post_score.text(score);
    },

    initShortcut: function () {
      var th = this;
      Mousetrap.bind('`', function() { th.set(REMOVE); });
      Mousetrap.bind('1', function() { th.set(GOOD); });
      Mousetrap.bind('2', function() { th.set(GREAT); });
      Mousetrap.bind('3', function() { th.set(FAVORITE); });
    }
  };
}).call(this, jQuery, I18n.scopify('js.vote'));

