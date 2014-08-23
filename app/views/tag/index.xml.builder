xml.instruct!
xml.tags do
  @tags.each do |tag|
    xml.tag tag.api_attributes
  end
end
