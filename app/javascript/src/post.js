/* globals jQuery, notesManager */
const $ = jQuery;

export default function postListeners () {
  let inLargerVersion = false;
  $('.highres-show').on('click', (e) => {
    e.preventDefault();

    if (inLargerVersion) return;

    inLargerVersion = true;
    const img = $('#image');
    const w = img.attr('large_width');
    const h = img.attr('large_height');
    $('#resized_notice').hide();
    img.hide();
    img.attr('src', '');
    img.attr('width', w);
    img.attr('height', h);
    img.attr('src', e.currentTarget.href);
    img.show();
    // TODO: create singleton and import instead of using global
    notesManager.all.invoke('adjustScale');
  });

  $('#post_tags').on('keydown', (e) => {
    if (e.target.closest('#quick-edit') != null) return;

    if (e.key === 'Enter') {
      e.preventDefault();
      document.getElementById('edit-form').requestSubmit();
    }
  });
}
