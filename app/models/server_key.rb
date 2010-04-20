class ServerKey < ActiveRecord::Base
  def self.[](key)
    begin
      ActiveRecord::Base.connection.select_value("SELECT value FROM server_keys WHERE name = '#{key}'")
    rescue Exception
      nil
    end
  end
end
