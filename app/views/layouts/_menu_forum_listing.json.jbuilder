json.forum_posts ForumPost.latest do |forum_post|
  json.(forum_post, :id, :pages, :title, :updated_at)
end
