import CheckAll from './classes/check_all'
import Comment from './classes/comment'
import Dmail from './classes/dmail'
import Favorite from './classes/favorite'
import ImageCrop from './classes/image_crop'
import ImgPoolHandler from './classes/img_pool_handler'
import InputHandler from './classes/input_handler'
import Menu from './classes/menu'
import MenuDragDrop from './classes/menu_drag_drop'
import MenuDropdown from './classes/menu_dropdown'
import NewsTicker from './classes/news_ticker'
import Note from './classes/note'
import NotesManager from './classes/notes_manager'
import Notice from './classes/notice'
import Pool from './classes/pool'
import PostLoader from './classes/post_loader'
import PostShowTabs from './classes/post_show_tabs'
import RelatedTags from './classes/related_tags'
import ThumbnailView from './classes/thumbnail_view'
import Timeago from './classes/timeago'
import UrlHashHandler from './classes/url_hash_handler'
import UserRecord from './classes/user_record'

window.Pool = new Pool
window.UrlHash = new UrlHashHandler
window.checkAll = new CheckAll
window.comment = new Comment
window.dmail = new Dmail
window.favorite = new Favorite
window.imageCrop = new ImageCrop
window.menu = new Menu
window.menuDragDrop = new MenuDragDrop
window.menuDropdown = new MenuDropdown
window.newsTicker = new NewsTicker
window.notesManager = new NotesManager
window.noticeInstance = new Notice
window.postShowTabs = new PostShowTabs
window.relatedTags = new RelatedTags
window.timeago = new Timeago
window.userRecord = new UserRecord

# FIXME: update to call instance method directly.
window.notice = noticeInstance.show


window.ImgPoolHandler = ImgPoolHandler
window.InputHandler = InputHandler
window.Note = Note
window.PostLoader = PostLoader
window.ThumbnailView = ThumbnailView
