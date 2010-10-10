#!/usr/bin/env ruby

# $Id: extconf.rb,v 1.8 2003/01/07 23:45:07 sean Exp $

require 'rbconfig'
require 'mkmf'

dir_config('libz')
dir_config('geoip')

$LIBPATH.push(Config::CONFIG['libdir'])
$CFLAGS += " -I#{Config::CONFIG['includedir']}"

def crash(str)
  printf(" extconf failure: %s\n", str)
  exit 1
end


unless have_library('z','gzopen')
  crash(<<EOL)
need libz.

	Install libz or try passing some of the following options
	to extconf.rb:

        --with-libz-dir=/path/to/libz
        --with-libz-lib=/path/to/libz/lib
        --with-libz-include=/path/to/libz/include
EOL
end

unless have_header('GeoIP.h') and
    have_header('GeoIPUpdate.h') and
    have_library('GeoIP', 'GeoIP_new') and
    have_library('GeoIPUpdate', 'GeoIP_update_database')
  crash(<<EOL)
need libGeoIP.

	Install the library or try passing one of the following
	options to extconf.rb:

        --with-geoip-dir=/path/to/geoip
        --with-geoip-lib=/path/to/geoip/lib
        --with-geoip-include=/path/to/geoip/include

        To obtain libGeoIP, yo ucan download it from:

        http://maxmind.com/geoip/api/c.shtml
EOL
end

$CFLAGS = ' -g -Wall ' + $CFLAGS

create_header()
create_makefile('net/geoip')
