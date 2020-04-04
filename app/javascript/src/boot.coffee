import CheckAll from './_classes/check_all'
import RelatedTags from './_classes/related_tags'

jQuery =>
  window.menuDragDrop = new MenuDragDrop

  Moebooru.postShowTabs.initialize()

window.relatedTags = new RelatedTags
window.checkAll = new CheckAll
Moe.timeago = new Moe.Timeago
