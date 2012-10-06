(function ($) {
  const remove = 0, good = 1, great = 2, favorite = 3;

  this.Vote = function (container, id) {
    var nodes = container.find('*');
    this.container = container;
    this.desc = nodes.filter('.vote-desc');
    this.stars = nodes.filter('.star-off');
    this.post_score = nodes.filter('#post-score-'+id);
    this.vote_up = nodes.filter('.vote-up');
    this.post_id = id;
    this.label = [t('vote.remove'), t('vote.good'), t('vote.great'), t('vote.fav')];
    this.setupEvents();
  };

  this.Vote.prototype = {
    set: function (vote) {
      var th = this;
      notice(t('voting')+'...');
      $.ajax({
        url: Moebooru.path('/post/vote.json'),
        data: {id: this.post_id, score: vote},
        dataType: 'json',
        type: 'post',
        statusCode: {
          403: function () { notice(t('error')+': '+t('denied')); }
        }
      }).done(function (data) {
        var score = data.posts[0].score;
        th.updateWidget(vote, score);
        notice(t('vote_saved'));
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
        for (var i = 1; i <= favorite; i++) {
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
        th.desc.html(th.label[score]);
        return false;
      });

      stars.on('mouseout', function () {
        for (var i = 1; i <= favorite; i++) {
          var star = $(stars[i]);
          star.removeClass('star-hovered');
          star.removeClass('star-unhovered');
          star.removeClass('star-hovered-after');
          star.removeClass('star-hovered-upto');
        }
        th.desc.html('');
        return false;
      });

      this.vote_up.on('click', function () {
        if (th.vote < favorite) return th.set(th.vote + 1);
        return false;
      });
    },

    updateWidget: function (vote, score) {
      this.vote = vote;
      for (var i = 1; i <= favorite; i++) {
        var star = $(this.stars[i]);
        if (i <= vote) {
          star.removeClass('star-set-after');
          star.addClass('star-set-upto');
        } else {
          star.removeClass('star-set-upto');
          star.addClass('star-set-after');
        }
      }
      this.post_score.html(score);
    }
  };
}).call(this, jQuery);

