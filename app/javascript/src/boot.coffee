import Rails from '@rails/ujs'
import Autocomplete from './classes/autocomplete'
import BrowserView from './classes/browser_view'
import CheckAll from './classes/check_all'
import Comment from './classes/comment'
import Dmail from './classes/dmail'
import Favorite from './classes/favorite'
import History from './classes/history'
import ImageCrop from './classes/image_crop'
import InlineImage from './classes/inline_image'
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
import PostQuickEdit from './classes/post_quick_edit'
import PostShowTabs from './classes/post_show_tabs'
import PreloadPosts from './classes/preload_posts'
import RelatedTags from './classes/related_tags'
import SimilarWithThumbnailing from './classes/similar_with_thumbnailing'
import TagCompletion from './classes/tag_completion'
import TagCompletionBox from './classes/tag_completion_box'
import ThumbnailUserImage from './classes/thumbnail_user_image'
import ThumbnailView from './classes/thumbnail_view'
import Timeago from './classes/timeago'
import UrlHashHandler from './classes/url_hash_handler'
import UserRecord from './classes/user_record'
import WindowTitleHandler from './classes/window_title_handler'

Rails.start()

window.History = new History
window.InlineImage = new InlineImage
window.Pool = new Pool
window.TagCompletion = new TagCompletion
window.UrlHash = new UrlHashHandler
window.autocomplete = new Autocomplete
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
window.preloadPosts = new PreloadPosts
window.relatedTags = new RelatedTags
window.timeago = new Timeago
window.userRecord = new UserRecord

# FIXME: update to call instance method directly.
window.notice = noticeInstance.show

window.BrowserView = BrowserView
window.InputHandler = InputHandler
window.Note = Note
window.PostLoader = PostLoader
window.PostQuickEdit = PostQuickEdit
window.SimilarWithThumbnailing = SimilarWithThumbnailing
window.TagCompletionBox = TagCompletionBox
window.ThumbnailUserImage = ThumbnailUserImage
window.ThumbnailView = ThumbnailView
window.WindowTitleHandler = WindowTitleHandler
