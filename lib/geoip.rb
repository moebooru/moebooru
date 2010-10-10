require 'vendor/plugins/net-geoip/geoip'

module GeoIP
  # Given an IP, return a two-letter country code.  If the IP isn't known or the GeoIP
  # database isn't available, return "??".
  def get_country_for_ip(ip)
    fn = "#{RAILS_ROOT}/vendor/plugins/net-geoip/GeoIP.dat"

    # GeoIP.open() will show an error if the file doesn't exist, and then return an instance
    # anyway and crash when we try to use it.  Make sure it exists.
    return "??" if not File.exists?(fn)

    g = Net::GeoIP.open(fn)
    country = g.country_code_by_addr(ip)
    return "??" if country.nil?
    return country
  end
  module_function :get_country_for_ip
end
