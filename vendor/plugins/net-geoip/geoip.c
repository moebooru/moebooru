/* $Id: geoip.c,v 1.6 2002/11/19 21:21:38 sean Exp $ */

#include "ruby_geoip.h"
#include "GeoIP.h"
#include "GeoIPUpdate.h"

VALUE ruby_net_geoip_country_code_by_addr(VALUE self, VALUE addr) {
  ruby_net_geoip *rng;
  char *cc;

  Check_Type(addr, T_STRING);
  Data_Get_Struct(self, ruby_net_geoip, rng);
  cc = (char *)GeoIP_country_code_by_addr(rng->g, STR2CSTR(addr));
  if (cc == NULL) {
    return(Qnil);
  } else {
    return(rb_str_new2(cc));
  }
}


VALUE ruby_net_geoip_country_code3_by_addr(VALUE self, VALUE addr) {
  ruby_net_geoip *rng;
  char *cc;

  Check_Type(addr, T_STRING);
  Data_Get_Struct(self, ruby_net_geoip, rng);
  cc = (char *)GeoIP_country_code3_by_addr(rng->g, STR2CSTR(addr));
  if (cc == NULL) {
    return(Qnil);
  } else {
    return(rb_str_new2(cc));
  }
}


VALUE ruby_net_geoip_country_code_by_name(VALUE self, VALUE name) {
  ruby_net_geoip *rng;
  char *cc;

  Check_Type(name, T_STRING);
  Data_Get_Struct(self, ruby_net_geoip, rng);
  cc = (char *)GeoIP_country_code_by_name(rng->g, STR2CSTR(name));
  if (cc == NULL) {
    return(Qnil);
  } else {
    return(rb_str_new2(cc));
  }
}


VALUE ruby_net_geoip_country_code3_by_name(VALUE self, VALUE name) {
  ruby_net_geoip *rng;
  char *cc;

  Check_Type(name, T_STRING);
  Data_Get_Struct(self, ruby_net_geoip, rng);
  cc = (char *)GeoIP_country_code3_by_name(rng->g, STR2CSTR(name));
  if (cc == NULL) {
    return(Qnil);
  } else {
    return(rb_str_new2(cc));
  }
}


VALUE ruby_net_geoip_country_id_by_addr(VALUE self, VALUE addr) {
  ruby_net_geoip *rng;
  Check_Type(addr, T_STRING);
  Data_Get_Struct(self, ruby_net_geoip, rng);
  return(INT2NUM(GeoIP_country_id_by_addr(rng->g, STR2CSTR(addr))));
}


VALUE ruby_net_geoip_country_id_by_name(VALUE self, VALUE name) {
  ruby_net_geoip *rng;
  Check_Type(name, T_STRING);
  Data_Get_Struct(self, ruby_net_geoip, rng);
  return(INT2NUM(GeoIP_country_id_by_name(rng->g, STR2CSTR(name))));
}


VALUE ruby_net_geoip_country_name_by_addr(VALUE self, VALUE addr) {
  ruby_net_geoip *rng;
  char *cn;

  Check_Type(addr, T_STRING);
  Data_Get_Struct(self, ruby_net_geoip, rng);
  cn = (char *)GeoIP_country_name_by_addr(rng->g, STR2CSTR(addr));
  if (cn == NULL) {
    return(Qnil);
  } else {
    return(rb_str_new2(cn));
  }
}


VALUE ruby_net_geoip_country_name_by_name(VALUE self, VALUE name) {
  ruby_net_geoip *rng;
  char *cn;

  Check_Type(name, T_STRING);
  Data_Get_Struct(self, ruby_net_geoip, rng);
  cn = (char *)GeoIP_country_name_by_name(rng->g, STR2CSTR(name));
  if (cn == NULL) {
    return(Qnil);
  } else {
    return(rb_str_new2(cn));
  }
}


void ruby_net_geoip_free(ruby_net_geoip *rng) {
  if (rng->g != NULL)
    GeoIP_delete(rng->g);

  free(rng);
}


VALUE ruby_net_geoip_new(int argc, VALUE *argv, VALUE class) {
  ruby_net_geoip *rng;
  int db_type;
  VALUE type;

  switch (argc) {
  case 0:
    db_type = GEOIP_STANDARD;
    break;
  case 1:
    rb_scan_args(argc, argv, "01", &type);
    Check_Type(type, T_FIXNUM);
    switch (NUM2INT(type)) {
    case GEOIP_STANDARD:
      db_type = NUM2INT(type);
      break;
    case GEOIP_MEMORY_CACHE:
      db_type = NUM2INT(type);
      break;
    default:
      rb_raise(rb_eArgError, "invalid database type: bust be TYPE_DISK or TYPE_RAM");
    }
    break;
  default:
    rb_raise(rb_eArgError, "wrong number of arguments (needs 0 or 1)");
  }
  rng = ALLOC(ruby_net_geoip);
  rng->g = GeoIP_new(db_type);

  return(Data_Wrap_Struct(class, 0, ruby_net_geoip_free, rng));
}


VALUE ruby_net_geoip_open(int argc, VALUE *argv, VALUE class) {
  ruby_net_geoip *rng;
  int db_type;
  VALUE filename, type;

  switch (argc) {
  case 1:
    rb_scan_args(argc, argv, "01", &filename);
    Check_Type(filename, T_STRING);
    db_type = GEOIP_STANDARD;
    break;
  case 2:
    rb_scan_args(argc, argv, "02", &filename, &type);
    Check_Type(filename, T_STRING);
    Check_Type(type, T_FIXNUM);

    switch (NUM2INT(type)) {
    case GEOIP_STANDARD:
      db_type = NUM2INT(type);
      break;
    case GEOIP_MEMORY_CACHE:
      db_type = NUM2INT(type);
      break;
    default:
      rb_raise(rb_eArgError, "invalid database type");
    }
    break;
  default:
    rb_raise(rb_eArgError, "wrong number of arguments (needs 0 or 1)");
  }
  rng = ALLOC(ruby_net_geoip);
  rng->g = GeoIP_open(STR2CSTR(filename), db_type);

  return(Data_Wrap_Struct(class, 0, ruby_net_geoip_free, rng));
}


VALUE ruby_net_geoip_database_info(VALUE self) {
  ruby_net_geoip *rng;
  Data_Get_Struct(self, ruby_net_geoip, rng);
  return(rb_str_new2(GeoIP_database_info(rng->g)));
}


VALUE ruby_net_geoip_region_by_addr(VALUE self, VALUE addr) {
  ruby_net_geoip *rng;
  GeoIPRegion *r;
  VALUE reg;

  Check_Type(addr, T_STRING);
  Data_Get_Struct(self, ruby_net_geoip, rng);
  r = GeoIP_region_by_addr(rng->g, STR2CSTR(addr));
  if (r == NULL)
    return(Qnil);

  reg = rb_str_new2(r->region);
  GeoIPRegion_delete(r);
  return(reg);
}


VALUE ruby_net_geoip_region_by_name(VALUE self, VALUE name) {
  ruby_net_geoip *rng;
  GeoIPRegion *r;
  VALUE reg;

  Check_Type(name, T_STRING);
  Data_Get_Struct(self, ruby_net_geoip, rng);
  r = GeoIP_region_by_name(rng->g, STR2CSTR(name));
  if (r == NULL)
    return(Qnil);

  reg = rb_str_new2(r->region);
  GeoIPRegion_delete(r);
  return(reg);
}


VALUE ruby_net_geoip_update_database(int argc, VALUE *argv, VALUE class) {
  int ret, debug;
  VALUE bool, key;

  if (argc == 1) {
    rb_scan_args(argc, argv, "10", &key);
    Check_Type(key, T_STRING);
    debug = 0;
  } else if (argc == 2) {
    rb_scan_args(argc, argv, "20", &key, &bool);
    switch (TYPE(bool)) {
    case T_TRUE:
      debug = 1;
      break;
    case T_FALSE:
      debug = 0;
      break;
    default:
      rb_raise(rb_eArgError, "Invalid argument: debug flag must be boolean");
    }
  } else {
    rb_raise(rb_eArgError, "wrong number of arguments (need 1 or 2)");
  }

  ret = GeoIP_update_database(STR2CSTR(key), debug, NULL);

  switch (ret) {
  case 0:           /* Success, database updated */
    return(Qtrue);
  case 1:           /* Database up-to-date, no action taken */
    return(Qfalse);
  case -1:
    rb_raise(eNetGeoIPError, "Invalid License Key in %s", STR2CSTR(key));
  case -11:
    rb_raise(eNetGeoIPError, "Unable to resolve hostname");
  case -12:
    rb_raise(eNetGeoIPError, "Non-IPv4 addres");
  case -13:
    rb_raise(eNetGeoIPError, "Error opening socket");
  case -14:
    rb_raise(eNetGeoIPError, "Unable to connect");
  case -15:
    rb_raise(eNetGeoIPError, "Unable to write GeoIP.dat.gz file");
  case -16:
    rb_raise(eNetGeoIPError, "Unable to write GeoIP.dat file");
  case -17:
    rb_raise(eNetGeoIPError, "Unable to read gzip data");
  case -18:
    rb_raise(eNetGeoIPError, "Out of memory error");
  case -19:
    rb_raise(eNetGeoIPError, "Error reading from socket, see errno");
  default:
    rb_raise(eNetGeoIPError, "Unknown error: contact the maintainer");
  }
}


void Init_geoip(void) {
  mNet = rb_define_module("Net");
  cNetGeoIP = rb_define_class_under(mNet, "GeoIP", rb_cObject);
  eNetGeoIPError = rb_define_class_under(cNetGeoIP, "Error", rb_eException);

  rb_define_const(cNetGeoIP, "TYPE_DISK", INT2NUM(GEOIP_STANDARD));
  rb_define_const(cNetGeoIP, "TYPE_RAM", INT2NUM(GEOIP_MEMORY_CACHE));
  rb_define_const(cNetGeoIP, "VERSION", rb_str_new2(RUBY_GEOIP_VERSION));
  rb_define_const(cNetGeoIP, "VERNUM", INT2NUM(RUBY_GEOIP_VERNUM));

  rb_define_singleton_method(cNetGeoIP, "new", ruby_net_geoip_new, -1);
  rb_define_singleton_method(cNetGeoIP, "open", ruby_net_geoip_open, -1);
  rb_define_singleton_method(cNetGeoIP, "update_database",
			     ruby_net_geoip_update_database, -1);

  rb_define_method(cNetGeoIP, "country_code_by_addr",
		   ruby_net_geoip_country_code_by_addr, 1);
  rb_define_method(cNetGeoIP, "country_code3_by_addr",
		   ruby_net_geoip_country_code3_by_addr, 1);
  rb_define_method(cNetGeoIP, "country_code_by_name",
		   ruby_net_geoip_country_code_by_name, 1);
  rb_define_method(cNetGeoIP, "country_code3_by_name",
		   ruby_net_geoip_country_code3_by_name, 1);
  rb_define_method(cNetGeoIP, "country_id_by_addr",
		   ruby_net_geoip_country_id_by_addr, 1);
  rb_define_method(cNetGeoIP, "country_id_by_name",
		   ruby_net_geoip_country_id_by_name, 1);
  rb_define_method(cNetGeoIP, "country_name_by_addr",
		   ruby_net_geoip_country_name_by_addr, 1);
  rb_define_method(cNetGeoIP, "country_name_by_name",
		   ruby_net_geoip_country_name_by_name, 1);
  rb_define_method(cNetGeoIP, "database_info",
		   ruby_net_geoip_database_info, 0);
  rb_define_method(cNetGeoIP, "region_by_addr",
		   ruby_net_geoip_region_by_addr, 1);
  rb_define_method(cNetGeoIP, "region_by_name",
		   ruby_net_geoip_region_by_name, 1);
}
