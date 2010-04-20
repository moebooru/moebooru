if true
  path = ""
  path += "#{RAILS_ROOT}/" if defined?(RAILS_ROOT)
  path += "public/javascripts"

  if not File.writable?(path)
    raise "Path must be writable: %s" % path
  end
end
