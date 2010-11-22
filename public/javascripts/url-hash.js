UrlHashHandler = function()
{
  this.observers = new Hash();
  this.last_hash = this.parse(this.get_raw_hash());

  this.hashchange_event = this.hashchange_event.bindAsEventListener(this);

  Element.observe(window, "hashchange", this.hashchange_event);
}

UrlHashHandler.prototype.fire_observers = function(old_hash, new_hash)
{
  var old_keys = old_hash.keys();
  var new_keys = this.last_hash.keys();
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

UrlHashHandler.prototype.hashchange_event = function(event)
{
  var old_hash = this.last_hash;
  var new_hash = this.parse(this.get_raw_hash());
  this.last_hash = new_hash;

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
  if(hash[0] == "#")
    hash = hash.substr(1);

  var hash_path = hash.split("?", 1)[0];

  var query_params = new Hash();
  query_params.set("", hash_path);

  var hash_query = hash.substr(hash_path.length+1);
  if(hash_query != "")
  {
    var hash_query_values = hash_query.split("&");
    for(var i = 0; i < hash_query_values.length; ++i)
    {
      var keyval = hash_query_values[i]; /* a=b */
      var key = keyval.split("=", 1)[0];
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
    s += window.encodeURIComponent(path);

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
  return this.last_hash.get(key);
}

/*
 * Set keys in the URL hash.
 *
 * UrlHash.set({id: 50});
 */
UrlHashHandler.prototype.set = function(hash)
{
  var old_hash = this.last_hash;

  var query_params = this.last_hash;
  query_params = query_params.merge(hash);

  var new_hash = this.construct(query_params);
  window.location.hash = new_hash;
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

