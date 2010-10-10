/* $Id: geoip.h,v 1.2 2002/09/28 04:51:09 sean Exp $ */

#ifndef __RUBY_GEOIP_H__
#define __RUBY_GEOIP_H__

/* Don't nuke this block!  It is used for automatically updating the
 * versions below. VERSION = string formatting, VERNUM = numbered
 * version for inline testing: increment both or none at all. */
#define RUBY_GEOIP_VERSION  "0.01"
#define RUBY_GEOIP_VERNUM   1

#include <ruby.h>
#include <rubyio.h>
#include <GeoIP.h>

VALUE mNet;
VALUE cNetGeoIP;
VALUE eNetGeoIPError;

typedef struct ruby_net_geoip {
  GeoIP *g;
} ruby_net_geoip;

#endif
