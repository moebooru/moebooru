UrlHashHandler = function()
{
  this.observers = new Hash();
  this.normalize = function(h) { }
  this.denormalize = function(h) { }

  this.current_hash = this.parse(this.get_raw_hash());
  this.normalize(this.current_hash);

  /* The last value received by the hashchange event: */
  this.last_hashchange = this.current_hash.clone();

  this.hashchange_event = this.hashchange_event.bindAsEventListener(this);

  Element.observe(window, "hashchange", this.hashchange_event);
}

UrlHashHandler.prototype.fire_observers = function(old_hash, new_hash)
{
  var all_keys = old_hash.keys();
  all_keys = all_keys.concat(new_hash.keys());
  all_keys = all_keys.uniq();

  var changed_hash_keys = [];
  all_keys.each(function(key) {
      var old_value = old_hash.get(key);
      var new_value = new_hash.get(key);
      if(old_value != new_value)
        changed_hash_keys.push(key);
  }.bind(this));

  var observers_to_call = [];
  changed_hash_keys.each(function(key) {
    var observers = this.observers.get(key);
    if(observers == null)
      return;
    observers_to_call = observers_to_call.concat(observers);
  }.bind(this));

  observers_to_call.each(function(observer) {
    observer(changed_hash_keys, old_hash, new_hash);
  });
}

/*
 * Set handlers to normalize and denormalize the URL hash.
 *
 * Denormalizing a URL hash can convert the URL hash to something clearer for URLs.  Normalizing
 * it reverses any denormalization, giving names to parameters.
 *
 * For example, if a normalized URL is
 *
 * http://www.example.com/app#show?id=1
 *
 * where the hash is {"": "show", id: "1"}, a denormalized URL may be
 *
 * http://www.example.com/app#show/1
 *
 * The denormalize callback will only be called with normalized input.  The normalize callback
 * may receive any combination of normalized or denormalized input.
 */
UrlHashHandler.prototype.set_normalize = function(norm, denorm)
{
  this.normalize = norm;
  this.denormalize = denorm;
  
  this.normalize(this.current_hash);
  this.set_all(this.current_hash.clone());
}

UrlHashHandler.prototype.hashchange_event = function(event)
{
  var old_hash = this.last_hashchange.clone();
  this.normalize(old_hash);

  var raw = this.get_raw_hash();
  var new_hash = this.parse(raw);
  this.normalize(new_hash);

  this.current_hash = new_hash.clone();
  this.last_hashchange = new_hash.clone();

  this.fire_observers(old_hash, new_hash);
}

/*
 * Parse a hash, returning a Hash.
 *
 * #a/b?c=d&e=f -> {"": 'a/b', c: 'd', e: 'f'}
 */
UrlHashHandler.prototype.parse = function(hash)
{
  if(hash == null)
    hash = "";
  if(hash.substr(0, 1) == "#")
    hash = hash.substr(1);

  var hash_path = hash.split("?", 1)[0];
  var hash_query = hash.substr(hash_path.length+1);

  hash_path = window.decodeURIComponent(hash_path);

  var query_params = new Hash();
  query_params.set("", hash_path);

  if(hash_query != "")
  {
    var hash_query_values = hash_query.split("&");
    for(var i = 0; i < hash_query_values.length; ++i)
    {
      var keyval = hash_query_values[i]; /* a=b */
      var key = keyval.split("=", 1)[0];

      /* If the key is blank, eg. "#path?a=b&=d", then ignore the value.  It'll overwrite
       * the path, which is confusing and never what's wanted. */
      if(key == "")
        continue;

      var value = keyval.substr(key.length+1);
      key = window.decodeURIComponent(key);
      value = window.decodeURIComponent(value);
      query_params.set(key, value);
    }
  }
  return query_params;
}

UrlHashHandler.prototype.construct = function(hash)
{
  var s = "#";
  var path = hash.get("");
  if(path != null)
  {
    /* For the path portion, we only need to escape the params separator ? and the escape
     * character % itself.  Don't use encodeURIComponent; it'll encode far more than necessary. */
    path = path.replace(/\?/g, "%3f").replace(/%/g, "%25");
    s += path;
  }

  var params = [];
  hash.each(function(k) {
    var key = k[0], value = k[1];
    if(key == "")
      return;
    if(value == null)
      return;

    key = window.encodeURIComponent(key);
    value = window.encodeURIComponent(value);
    params.push(key + "=" + value);
  });
  if(params.length != 0)
    s += "?" + params.join("&");

  return s;
}

UrlHashHandler.prototype.get_raw_hash = function()
{
  /*
   * Firefox doesn't handle window.location.hash correctly; it decodes the contents,
   * where all other browsers give us the correct data.  http://stackoverflow.com/questions/1703552
   */
  var pre_hash_part = window.location.href.split("#", 1)[0];
  return window.location.href.substr(pre_hash_part.length);
}

UrlHashHandler.prototype.get = function(key)
{
  return this.current_hash.get(key);
}

/*
 * Set keys in the URL hash.
 *
 * UrlHash.set({id: 50});
 */
UrlHashHandler.prototype.set = function(hash)
{
  var new_hash = this.current_hash.merge(hash);
  this.normalize(new_hash);
  this.set_all(new_hash);
}

UrlHashHandler.prototype.set_all = function(query_params)
{
  query_params = query_params.clone();

  this.normalize(query_params);
  this.current_hash = query_params.clone();

  this.denormalize(query_params);

  var new_hash = this.construct(query_params);
  if(window.location.hash != new_hash)
    window.location.hash = new_hash;

  /* Explicitly fire the hashchange event, so it's handled quickly even if the browser
   * doesn't support the event.  It's harmless if we get this event multiple times due
   * to the browser delivering it normally due to our change. */
  this.hashchange_event(null);
}


UrlHashHandler.prototype.observe = function(key, func)
{
  var observers = this.observers.get(key);
  if(observers == null)
  {
    observers = [];
    this.observers.set(key, observers);
  }

  if(observers.indexOf(func) != -1)
    return;

  observers.push(func);
}

UrlHashHandler.prototype.stopObserving = function(key, func)
{
  var observers = this.observers.get(key);
  if(observers == null)
    return;

  observers = observers.without(func);
  this.observers.set(key, observers);
}

UrlHash = new UrlHashHandler();

