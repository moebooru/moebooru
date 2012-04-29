if true
  path = ""
  path += "#{Rails.root}/" if defined?(RAILS_ROOT)
  path += "public/javascripts"

  if not File.writable?(path)
    raise "Path must be writable: %s" % path
  end
end
