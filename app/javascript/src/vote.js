/* global favorite, I18n, jQuery, Moebooru, notice, User */
import Mousetrap from 'mousetrap';

const $ = jQuery;
const t = I18n.scopify('js.vote');

const REMOVE = 0;
const GOOD = 1;
const GREAT = 2;
const FAVORITE = 3;

const label = [
  t('.remove'),
  t('.good'),
  t('.great'),
  t('.fav')
];

const shortcutMapping = [
  ['`', REMOVE],
  ['1', GOOD],
  ['2', GREAT],
  ['3', FAVORITE]
];

function getScore (star) {
  return parseInt(star.dataset.star, 10);
}

export default class Vote {
  data = {
    score: null,
    vote: null
  };

  desc;
  post_score;
  post_id;
  stars;
  vote_up;

  constructor (container, id) {
    const nodes = container.find('*');
    this.desc = nodes.filter('.vote-desc');
    this.stars = nodes.filter('.star-off');
    this.post_score = nodes.filter(`#post-score-${id}, .post-score`);
    this.vote_up = nodes.filter('.vote-up');
    this.post_id = id;
    this.setupEvents();
  }

  set = (vote) => {
    User.run_login(false, () => {
      notice(t('.voting'));
      $.ajax({
        url: Moebooru.path('/post/vote.json'),
        data: {
          id: this.post_id,
          score: vote
        },
        dataType: 'json',
        type: 'post',
        statusCode: {
          403 () {
            notice(`${t('js.error')}${t('js.denied')}`);
          }
        }
      }).done((data) => {
        this.updateWidget(vote, data.posts[0].score);
        $('#favorited-by').html(favorite.linkToUsers(data.voted_by[FAVORITE]));
        notice(t('.saved'));
      });
    });
  };

  setupEvents () {
    this.stars.on('click', (e) => {
      e.preventDefault();
      this.set(getScore(e.currentTarget));
    });

    this.stars.on('mouseover', (e) => {
      this.setMouseover(e.currentTarget);
    });

    this.stars.on('mouseout', (e) => {
      this.setMouseover(null);
    });

    this.vote_up.on('click', (e) => {
      e.preventDefault();
      if (this.vote < FAVORITE) {
        this.set(this.vote + 1);
      }
    });

    $('#add-to-favs > a').on('click', (e) => {
      e.preventDefault();
      this.set(FAVORITE);
    });

    $('#remove-from-favs > a').on('click', (e) => {
      e.preventDefault();
      this.set(GREAT);
    });
  }

  updateWidget (vote, targetScore) {
    const add = $('#add-to-favs');
    const rm = $('#remove-from-favs');
    this.vote = vote || 0;
    this.data.score = targetScore;
    this.data.vote = vote;

    for (const star of this.stars) {
      const score = getScore(star);
      const $star = $(star);
      if (score <= vote) {
        $star.removeClass('star-set-after');
        $star.addClass('star-set-upto');
      } else {
        $star.removeClass('star-set-upto');
        $star.addClass('star-set-after');
      }
    }

    if (vote === FAVORITE) {
      add.hide();
      rm.show();
    } else {
      add.show();
      rm.hide();
    }
    this.post_score.text(targetScore);
  }

  initShortcut () {
    for (const [key, value] of shortcutMapping) {
      Mousetrap.bind(key, () => this.set(value));
    }
  }

  setMouseover (targetStar) {
    if (targetStar != null && !targetStar.classList.contains('star')) {
      targetStar = $(targetStar).closest('.star')[0];
    }

    if (targetStar == null) {
      this.mouseout();
      return;
    }

    const targetScore = getScore(targetStar);

    for (const star of this.stars) {
      const score = getScore(star);
      const $star = $(star);

      if (score <= targetScore) {
        $star.removeClass('star-hovered-after');
        $star.addClass('star-hovered-upto');
      } else {
        $star.removeClass('star-hovered-upto');
        $star.addClass('star-hovered-after');
      }
      if (score !== targetScore) {
        $star.removeClass('star-hovered');
        $star.addClass('star-unhovered');
      } else {
        $star.removeClass('star-unhovered');
        $star.removeClass('star-hovered');
      }
    }

    this.desc.text(label[targetScore]);
  }

  mouseout () {
    for (const star of this.stars) {
      star.classList.remove('star-hovered', 'star-unhovered', 'star-hovered-after', 'star-hovered-upto');
    }

    this.desc.text('');
  }

  activateItem (targetStar) {
    if (targetStar == null) {
      return;
    }

    if (!targetStar.classList.contains('star')) {
      targetStar = $(targetStar).closest('.star')[0];
    }

    if (targetStar == null) {
      return;
    }

    const score = getScore(targetStar);
    this.set(score);

    return score;
  }
}
