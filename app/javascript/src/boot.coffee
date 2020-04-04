import CheckAll from './_classes/check_all'
import RelatedTags from './_classes/related_tags'
import Timeago from './_classes/timeago'

jQuery =>
  Moebooru.postShowTabs.initialize()

window.menuDragDrop = new MenuDragDrop
window.relatedTags = new RelatedTags
window.checkAll = new CheckAll
window.timeago = new Timeago
