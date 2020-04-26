import CheckAll from './classes/check_all'
import Comment from './classes/comment'
import Dmail from './classes/dmail'
import Favorite from './classes/favorite'
import ImageCrop from './classes/image_crop'
import Menu from './classes/menu'
import MenuDragDrop from './classes/menu_drag_drop'
import MenuDropdown from './classes/menu_dropdown'
import NewsTicker from './classes/news_ticker'
import Notice from './notice'
import PostShowTabs from './classes/post_show_tabs'
import RelatedTags from './classes/related_tags'
import Timeago from './classes/timeago'
import UserRecord from './classes/user_record'

window.checkAll = new CheckAll
window.comment = new Comment
window.dmail = new Dmail
window.favorite = new Favorite
window.imageCrop = new ImageCrop
window.menu = new Menu
window.menuDragDrop = new MenuDragDrop
window.menuDropdown = new MenuDropdown
window.newsTicker = new NewsTicker
window.noticeInstance = new Notice
window.postShowTabs = new PostShowTabs
window.relatedTags = new RelatedTags
window.timeago = new Timeago
window.userRecord = new UserRecord

# FIXME: update to call instance method directly.
window.notice = noticeInstance.show
