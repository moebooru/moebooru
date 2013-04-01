json.id @pool.id
json.name @pool.name
json.created_at @pool.created_at
json.updated_at @pool.updated_at
json.user_id @pool.user_id
json.is_public @pool.is_public
json.post_count @pool.post_count
json.description @pool.description
json.posts @posts do |p|
  json.id p.id
  json.tags p.tags
  json.created_at p.created_at
  json.creator_id p.user_id
  json.author p.author
  json.change p.change_seq
  json.source p.source
  json.score p.score
  json.md5 p.md5
  json.file_size p.file_size
  json.file_url p.file_url
  json.is_shown_in_index p.is_shown_in_index
  json.preview_url p.preview_url
  json.preview_width p.preview_dimensions[0]
  json.preview_height p.preview_dimensions[1]
  json.actual_preview_width p.raw_preview_dimensions[0]
  json.actual_preview_height p.raw_preview_dimensions[1]
  json.sample_url p.sample_url
  json.sample_width p.sample_width || width
  json.sample_height p.sample_height || height
  json.sample_file_size p.sample_size
  json.jpeg_url p.jpeg_url
  json.jpeg_width p.jpeg_width || width
  json.jpeg_height p.jpeg_height || height
  json.jpeg_file_size p.jpeg_size
  json.rating p.rating
  json.has_children p.has_children
  json.parent_id p.parent_id
  json.status p.status
  json.width p.width
  json.height p.height
  json.is_held p.is_held
  json.frames_pending_string p.frames_pending
  json.frames_pending p.frames_api_data(p.frames_pending)
  json.frames_string p.frames
  json.frames p.frames_api_data(p.frames)
end
