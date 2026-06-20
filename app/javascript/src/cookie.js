/* globals Vars */
import BaseCookies from 'js-cookie';

// welp
// Reference: https://github.com/js-cookie/js-cookie/blob/3f2b5e6884407c54b391483f39ddcd4c70f9243c/SERVER_SIDE.md
export const Cookies = BaseCookies
  .withConverter({
    write: BaseCookies.converter.write,
    read: (value) => BaseCookies.converter.read(value.replace(/\+/g, ' '))
  }).withAttributes({
    path: Vars.prefix,
    expires: 365
  });

export const Cookie = {
  put (name, value, days) {
    const options = { expires: days || undefined };

    return Cookies.set(name, value, options);
  },

  get (name) {
    // FIXME: compatibility reason. Should sweep this with !! check
    //        or something similar in relevant codes.
    return Cookies.get(name) || '';
  },

  get_int (name) {
    return parseInt(Cookies.get(name), 10);
  },

  remove (name) {
    return Cookies.remove(name);
  },

  unescape (value) {
    return window.decodeURIComponent(value.replace(/\+/g, ' '));
  }
};
