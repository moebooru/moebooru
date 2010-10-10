# $Id: tc_Net::GeoIP.rb,v 1.4 2002/10/08 21:14:47 sean Exp $

class TC_Net_GeoIP < Test::Unit::TestCase
  def set_up()
    @g = Net::GeoIP.new()
    assert(@g)
    @bad_ips  = ['66.250.180.0']
    @bad_names = ['tgd.net']
    @good_ips = [['64.81.67.0','US','USA','United States',225],['210.157.158.0','JP','JPN','Japan',111]]
    @good_names = [['whitehouse.gov','US','United States',225],['freebsd.org','US','United States',225]]
  end

  def tear_down()
    @g = nil
    @bad_ips = nil
    @bad_names = nil
    @good_ips = nil
    @good_names = nil
  end


  def test_net_geoip_constants()
    assert_instance_of(String, Net::GeoIP::VERSION)
    assert_instance_of(Fixnum, Net::GeoIP::VERNUM)
    assert_instance_of(Fixnum, Net::GeoIP::TYPE_DISK)
    assert_instance_of(Fixnum, Net::GeoIP::TYPE_RAM)
  end


  def test_net_geoip_country_code_by_addr()
    for ip in @good_ips
      assert_instance_of(ip[1].class, @g.country_code_by_addr(ip[0]))
      assert_equal(ip[1], @g.country_code_by_addr(ip[0]))
    end

    for ip in @bad_ips
      assert_instance_of(NilClass, @g.country_code_by_addr(ip))
    end
  end


  def test_net_geoip_country_code3_by_addr()
    for ip in @good_ips
      assert_instance_of(ip[2].class, @g.country_code3_by_addr(ip[0]))
      assert_equal(ip[2], @g.country_code3_by_addr(ip[0]))
    end

    for ip in @bad_ips
      assert_instance_of(NilClass, @g.country_code3_by_addr(ip))
    end
  end


  def test_net_geoip_country_name_by_addr()
    for ip in @good_ips
      assert_instance_of(ip[3].class, @g.country_name_by_addr(ip[0]))
      assert_equal(ip[3], @g.country_name_by_addr(ip[0]))
    end

    for ip in @bad_ips
      assert_instance_of(NilClass, @g.country_name_by_addr(ip))
    end
  end


  def test_net_geoip_country_id_by_addr()
    for ip in @good_ips
      assert_instance_of(ip[4].class, @g.country_id_by_addr(ip[0]))
      assert_equal(ip[4], @g.country_id_by_addr(ip[0]))
    end

    for ip in @bad_ips
      assert_equal(0, @g.country_id_by_addr(ip))
    end
  end


  def test_net_geoip_country_code_by_name()
    for name in @good_names
      assert_instance_of(name[1].class, @g.country_code_by_name(name[0]))
      assert_equal(name[1], @g.country_code_by_addr(name[0]))
    end

    for name in @bad_names
      assert_instance_of(NilClass, @g.country_code_by_name(name))
    end
  end


  def test_net_geoip_country_name_by_name()
    for name in @good_names
      assert_instance_of(name[2].class, @g.country_name_by_name(name[0]))
      assert_equal(name[2], @g.country_name_by_addr(name[0]))
    end

    for name in @bad_names
      assert_instance_of(NilClass, @g.country_name_by_name(name))
    end
  end


  def test_net_geoip_country_id_by_name()
    for name in @good_names
      assert_instance_of(name[3].class, @g.country_id_by_name(name[0]))
      assert_equal(name[3], @g.country_id_by_addr(name[0]))
    end

    for name in @bad_names
      assert_equal(0, @g.country_id_by_name(name))
    end
  end


  def test_net_geoip_database_info()
    assert_instance_of(String, @g.database_info)
  end


  def test_net_geoip_update_database()
    # assert_raises(Net::GeoIP::Error) do
    #  @Net::GeoIP.update_database('ruby-Net::GeoIP-test-bad_key', false)
    # end
  end
end
