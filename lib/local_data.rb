# This simulates an http.request_get response, for data: URLs.
class LocalData
  def initialize(data)
    @data = data
  end

  def read_body
    yield @data
  end
end
