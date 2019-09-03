#= require moebooru
#= require moebooru/related_tags
#= require moebooru/post_show_tabs
jQuery =>
  @Moebooru.relatedTags = new Moebooru.RelatedTags

  Moebooru.postShowTabs.initialize()
