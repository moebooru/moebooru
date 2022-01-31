import PreloadContainer from './preload_container'

$ = jQuery

# Parse `.js-preload-posts` and preload the specified non-blacklisted posts
# The JSON should be an array of object `{ id, url }`.
export default class PreloadPosts
  constructor: ->
    @urls = new Set

    $ => @exec()


  exec: =>
    @getUrlsFromDocument()

    return if @urls.size == 0

    container = new PreloadContainer
    @urls.forEach (url) => container.preload url


  getUrlsFromDocument: =>
    for postsJson in document.querySelectorAll('.js-preload-posts')
      @getUrlsFromJson(JSON.parse(postsJson.text))


  getUrlsFromJson: (json) =>
    for post in json when !Post.is_blacklisted(post.id)
      @urls.add(post.url)
