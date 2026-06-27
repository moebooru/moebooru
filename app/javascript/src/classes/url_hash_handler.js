/* globals Element, Hash */
export default class UrlHashHandler {
  constructor () {
    this.observers = new Hash();
    this.normalize = (h) => {};
    this.denormalize = (h) => {};
    this.deferred_sets = [];
    this.deferred_replace = false;
    this.current_hash = this.parse(this.get_raw_hash());
    this.normalize(this.current_hash);
    // The last value received by the hashchange event:
    this.last_hashchange = this.current_hash.clone();
    Element.observe(window, 'hashchange', this.hashchange_event);
  }

  fire_observers (oldHash, newHash) {
    let allKeys = oldHash.keys();
    allKeys = allKeys.concat(newHash.keys());
    allKeys = allKeys.uniq();
    const changedHashKeys = [];
    allKeys.each(function (key) {
      const oldValue = oldHash.get(key);
      const newValue = newHash.get(key);
      if (oldValue !== newValue) {
        changedHashKeys.push(key);
      }
    });
    let observersToCall = [];
    changedHashKeys.each((key) => {
      const observers = this.observers.get(key);
      if (observers == null) {
        return;
      }
      observersToCall = observersToCall.concat(observers);
    });
    const universalObservers = this.observers.get(null);
    if (universalObservers != null) {
      observersToCall = observersToCall.concat(universalObservers);
    }
    observersToCall.each(function (observer) {
      observer(changedHashKeys, oldHash, newHash);
    });
  }

  // Set handlers to normalize and denormalize the URL hash.

  // Denormalizing a URL hash can convert the URL hash to something clearer for URLs.  Normalizing
  // it reverses any denormalization, giving names to parameters.

  // For example, if a normalized URL is

  // http://www.example.com/app#show?id=1

  // where the hash is {"": "show", id: "1"}, a denormalized URL may be

  // http://www.example.com/app#show/1

  // The denormalize callback will only be called with normalized input.  The normalize callback
  // may receive any combination of normalized or denormalized input.
  set_normalize (norm, denorm) {
    this.normalize = norm;
    this.denormalize = denorm;
    this.normalize(this.current_hash);
    this.set_all(this.current_hash.clone());
  }

  hashchange_event = (event) => {
    const oldHash = this.last_hashchange.clone();
    this.normalize(oldHash);
    const raw = this.get_raw_hash();
    const newHash = this.parse(raw);
    this.normalize(newHash);
    this.current_hash = newHash.clone();
    this.last_hashchange = newHash.clone();
    this.fire_observers(oldHash, newHash);
  };

  // Parse a hash, returning a Hash.
  // #a/b?c=d&e=f -> {"": 'a/b', c: 'd', e: 'f'}
  parse (hash) {
    hash ??= '';
    if (hash.substr(0, 1) === '#') {
      hash = hash.substr(1);
    }
    let hashPath = hash.split('?', 1)[0];
    const hashQuery = hash.substr(hashPath.length + 1);
    hashPath = window.decodeURIComponent(hashPath);
    const queryParams = new Hash();
    queryParams.set('', hashPath);
    if (hashQuery !== '') {
      for (const keyval of hashQuery.split('&')) {
        // a=b
        let key = keyval.split('=', 1)[0];
        // If the key is blank, eg. "#path?a=b&=d", then ignore the value.  It'll overwrite
        // the path, which is confusing and never what's wanted.
        if (key === '') {
          continue;
        }
        let value = keyval.substr(key.length + 1);
        key = window.decodeURIComponent(key);
        value = window.decodeURIComponent(value);
        queryParams.set(key, value);
      }
    }
    return queryParams;
  }

  construct (hash) {
    let s = '#';
    let path = hash.get('');
    if (path != null) {
      // For the path portion, we only need to escape the params separator ? and the escape
      // character % itself.  Don't use encodeURIComponent; it'll encode far more than necessary.
      path = path.replace(/%/g, '%25').replace(/\?/g, '%3f');
      s += path;
    }
    const params = [];
    hash.each(function (k) {
      let key = k[0];
      let value = k[1];
      if (key === '') {
        return;
      }
      if (value == null) {
        return;
      }
      key = window.encodeURIComponent(key);
      value = window.encodeURIComponent(value);
      params.push(key + '=' + value);
    });
    if (params.length !== 0) {
      s += '?' + params.join('&');
    }
    return s;
  }

  get_raw_hash () {
    return window.location.hash.slice(1);
  }

  set_raw_hash (hash) {
    const queryParams = this.parse(hash);
    this.set_all(queryParams);
  }

  get (key) {
    return this.current_hash.get(key);
  }

  // Set keys in the URL hash.

  // UrlHash.set({id: 50});

  // If replace is true and the History API is available, replace the state instead
  // of pushing it.
  set (hash, replace) {
    const newHash = this.current_hash.merge(hash);
    this.normalize(newHash);
    this.set_all(newHash, replace);
  }

  /**
   * Each call to UrlHash.set() will immediately set the new hash, which will create a new
   * browser history slot.  This isn't always wanted.  When several changes are being made
   * in response to a single action, all changes should be made simultaeously, so only a
   * single history slot is created.  Making only a single call to set() is difficult when
   * these changes are made by unrelated parts of code.
   *
   * Defer changes to the URL hash.  If several calls are made in quick succession, buffer
   * the changes.  When a short timer expires, make all changes at once.  This will never
   * happen before the current Javascript call completes, because timers will never interrupt
   * running code.
   *
   * UrlHash.set() doesn't do this, because set() guarantees that the hashchange event will
   * be fired and complete before the function returns.
   *
   * If replace is true and the History API is available, replace the state instead of pushing
   * it.  If any set_deferred call consolidated into a single update has replace = false, the
   * new state will be pushed.
   */
  set_deferred (hash, replace) {
    this.deferred_sets.push(hash);
    if (replace) {
      this.deferred_replace = true;
    }
    const set = () => {
      this.deferred_set_timer = null;
      let newHash = this.current_hash;
      this.deferred_sets.each(function (m) {
        newHash = newHash.merge(m);
      });
      this.normalize(newHash);
      this.set_all(newHash, this.deferred_replace);
      this.deferred_sets = [];
      this.hashchange_event(null);
      this.deferred_replace = false;
    };
    if (this.deferred_set_timer == null) {
      this.deferred_set_timer = set.defer();
    }
  }

  set_all (queryParams, replace) {
    queryParams = queryParams.clone();
    this.normalize(queryParams);
    this.current_hash = queryParams.clone();
    this.denormalize(queryParams);
    const newHash = this.construct(queryParams);
    if (window.location.hash !== newHash) {
      // If the History API is available, use it to support URL replacement.  FF4.0's pushState
      // is broken; don't use it.
      if (window.history && window.history.replaceState && window.history.pushState && !navigator.userAgent.match('Firefox/[45].')) {
        const url = window.location.protocol + '//' + window.location.host + window.location.pathname + newHash;
        if (replace) {
          window.history.replaceState({}, window.title, url);
        } else {
          window.history.pushState({}, window.title, url);
        }
      } else {
        window.location.hash = newHash;
      }
    }
    // Explicitly fire the hashchange event, so it's handled quickly even if the browser
    // doesn't support the event.  It's harmless if we get this event multiple times due
    // to the browser delivering it normally due to our change.
    this.hashchange_event(null);
  }

  // Observe changes to the specified key.  If key is null, watch for all changes.
  observe (key, func) {
    let observers;
    observers = this.observers.get(key);
    if (observers == null) {
      observers = [];
      this.observers.set(key, observers);
    }
    if (observers.indexOf(func) !== -1) {
      return;
    }
    observers.push(func);
  }

  stopObserving (key, func) {
    let observers;
    observers = this.observers.get(key);
    if (observers == null) {
      return;
    }
    observers = observers.without(func);
    this.observers.set(key, observers);
  }
}
