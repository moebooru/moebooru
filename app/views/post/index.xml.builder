xml.instruct!
xml.posts(:count => @posts.total_entries, :offset => (@posts.current_page - 1) * @posts.per_page) do
  @posts.each do |post|
    post.to_xml(:builder => xml, :skip_instruct => true)
  end
end
