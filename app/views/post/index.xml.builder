xml.instruct!
xml.posts(:count => @posts.total_entries, :offset => (@posts.current_page - 1) * @posts.per_page) do
  @posts.each do |post|
    xml.post(post.api_attributes)
  end
end
