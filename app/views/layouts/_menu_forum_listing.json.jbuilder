json.forum_posts ForumPost.latest do |forum_post|
  json.call(forum_post, :id, :pages, :title, :updated_at)
end
