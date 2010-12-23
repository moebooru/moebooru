/* 
 * The tag blob looks like this:
 *
 * 1:tagme 2:fixed
 *
 * where the initial number is the tag type, and a space after each tag is guaranteed, including
 * after the final one.  Spaces and colons are disallowed in tags, so they don't need escaping.
 * This can be searched quickly with regexes:
 *
 * ':tagme '   - whole tag match
 * ':tag'      - tag prefix match
 * ':t[^ ]*g'  - substring match
 * ':[^ ]*me '  - suffix match
 * ':[^ ]*t[^ ]*g[^ ]*m' - ordered character match
 */
TagCompletionClass = function()
{
  /* Don't load the tag data out of localStorage until it's needed. */
  this.loading = false;
  this.loaded = false;

  /* If the data format is out of date, clear it. */
  if(localStorage.tag_data_format != 2)
  {
    delete localStorage.tag_data;
    delete localStorage.tag_data_version;
    delete localStorage.recent_tags;
    localStorage.tag_data_format = 2;
  }

  /* Pull in recent tags.  This is entirely local data and not too big, so always load it. */
  this.recent_tags = localStorage.recent_tags || "";

  this.load_data_complete_callbacks = [];
}

TagCompletionClass.prototype.init = function(current_version)
{
  if(this.loaded)
    return;
  this.most_recent_tag_data_version = current_version;
}

/*
 * If we havn't loaded the data yet, do so now.  If the data is already loaded, call onComplete
 * immediately; otherwise call it when the data finishes loading.
 *
 * If this is called multiple times before the tag load completes, the data will only be loaded
 * once, but all callbacks will be called.
 */
TagCompletionClass.prototype.load_data = function(onComplete)
{
  /* If we're already fully loaded, just run the callback and return. */
  if(this.loaded)
  {
    if(onComplete)
      onComplete();
    return;
  }

  /* Add the callback to the list. */
  if(onComplete)
    this.load_data_complete_callbacks.push(onComplete);

  /* If we're already loading, let the existing request finish; it'll run the callback. */
  if(this.loading)
    return;
  this.loading = true;

  var complete = function()
  {
    this.loading = false;
    this.loaded = true;

    /* Now that we have the tag types loaded, update any tag types that we have loaded. */
    this.update_tag_types();

    var callbacks = this.load_data_complete_callbacks;
    this.load_data_complete_callbacks = [];

    callbacks.each(function(callback) {
      callback();
    }.bind(this));
  }.bind(this);

  /* If we've been told the current tag data revision and we're already on it, or if we havn't
   * been told the revision at all, use the data we have. */
  if(localStorage.tag_data != null)
  {
    if(this.most_recent_tag_data_version == null || localStorage.tag_data_version == this.most_recent_tag_data_version)
    {
      // console.log("Already on most recent tag data version");
      this.tag_data = localStorage.tag_data;
      complete();
      return;
    }
  }
  
  /* Requeset the tag data from the server.  Tell the server the data version we already
   * have. */
  var params = {};
  if(localStorage.tag_data_version != null)
    params.version = localStorage.tag_data_version;

  var req = new Ajax.Request("/tag/summary.json", {
    parameters: params,
    onSuccess: function(resp)
    {
      var json = resp.responseJSON;

      /* If unchanged is true, tag_data_version is already current; this means we weren't told
       * the current data revision to start with but we're already up to date. */
      if(json.unchanged)
      {
        // console.log("Tag data unchanged");
        this.tag_data = localStorage.tag_data;
        complete();
        return;
      }

      /* We've received new tag data; save it. */
      // console.log("Storing new tag data");
      this.tag_data = json.data;
      localStorage.tag_data = this.tag_data;
      localStorage.tag_data_version = json.version;

      complete();
    }.bind(this)
  });
}

/* When form is submitted, call add_recent_tags_from_update for the given tags and old_tags
 * fields. */
TagCompletionClass.prototype.observe_tag_changes_on_submit = function(form, tags_field, old_tags_field)
{
  return form.on("submit", function(e) {
    var old_tags = old_tags_field? old_tags_field.value:"";
    TagCompletion.add_recent_tags_from_update(tags_field.value, old_tags);
  });
}

/* From a tag string, eg. "1:tagme:alias:alias2:", retrieve the tag name "tagme". */
var get_tag_from_string = function(tag_string)
{
  var m = tag_string.match(/\d+:([^:]*):.*/);
  if(!m)
    throw "Unparsable cached tag: '" + tag_string + "'";
  return m[1];
}

/* Update the cached types of all known tags in tag_data and recent_tags. */
TagCompletionClass.prototype.update_tag_types_for_list = function(tags, allow_add)
{
  var tag_map = {};

  /* Make a mapping of tags to indexes. */
  var split_tags = tags.split(" ");
  var idx = 0;
  split_tags.each(function(tag) {
    if(tag == "")
      return;
    var tag_name = get_tag_from_string(tag);

    tag_map[tag_name] = idx;
    ++idx;
  });

  /*
   * For each known tag type, mark the type in the tag cache.  We receive this info when
   * we download the tag types, so this is just updating any changes. 
   *
   * This is set up to iterate only over known types, and not over the entire list of
   * tags, so when we have a lot of tags we minimize the amount of work we have to do
   * on every tag.
   */
  Post.tag_types.each(function(tag_and_type) {
    var tag = tag_and_type[0];
    var tag_type = tag_and_type[1];
    var tag_type_idx = Post.tag_type_names.indexOf(tag_type);
    if(tag_type_idx == -1)
      throw "Unknown tag type " + tag_type;

    if(!(tag in tag_map))
    {
      /* This tag is known in Post.tag_types, but isn't a known tag.  If allow_add is true,
       * add it to the end.  This is for updating new tags that have shown up on the server,
       * not for adding new recent tags. */
      if(allow_add)
      {
        var tag_string = tag_type_idx + ":" + tag;
        split_tags.push(tag_string);
      }
    }
    else
    {
      /* This is a known tag; this is the usual case.  Parse out the complete tag from the
       * original string, and update the tag type index. */
      var tag_idx = tag_map[tag];
      var existing_tag = split_tags[tag_idx];

      var m = existing_tag.match(/\d+(:.*)/);
      var new_tag_string = tag_type_idx + m[1];

      split_tags[tag_idx] = new_tag_string;
    }
  });

  return split_tags.join(" ");
}

TagCompletionClass.prototype.update_tag_types = function()
{
  /* This function is always called, because we receive tag type data for most pages.
   * Only actually update tag types if the tag data is already loaded. */
  if(!this.loaded)
    return;

  /* Update both tag_data and recent_tags; only add new entries to tag_data. */
  this.tag_data = this.update_tag_types_for_list(this.tag_data, true);
  localStorage.tag_data = this.tag_data;

  this.recent_tags = this.update_tag_types_for_list(this.recent_tags, false);
  localStorage.recent_tags = this.recent_tags;
}

TagCompletionClass.prototype.create_tag_search_regex = function(tag, options)
{
  /* Split the tag by character. */
  var letters = tag.split("");

  /*
   * We can do a few search methods:
   *
   * 1: Ordinary prefix search.
   * 2: Name search. "aaa_bbb" -> "aaa*_bbb*|bbb*_aaa*".
   * 3: Contents search; "tgm" -> "t*g*m*" -> "tagme".  The first character is still always
   * matched exactly.
   *
   * Avoid running multiple expressions.  Instead, combine these into a single one, then run
   * each part on the results to determine which type of result it is.  Always show prefix and
   * name results before contents results.
   */
  var regex_parts = [];

  /* Allow basic word prefix matches.  "tag" matches at the beginning of any word
   * in a tag, eg. both "tagme" and "dont_tagme". */
  /* Add the regex for ordinary prefix matches. */
  var s = "(([^:]*_)?";
  letters.each(function(letter) {
    var escaped_letter = RegExp.escape(letter);
    s += escaped_letter;
  });
  s += ")";
  regex_parts.push(s);

  /* Allow "fir_las" to match both "first_last" and "last_first". */
  if(tag.indexOf("_") != -1)
  {
    var first = tag.split("_", 1)[0];
    var last = tag.slice(first.length + 1);

    first = RegExp.escape(first);
    last = RegExp.escape(last);

    var s = "(";
    s += "(" + first + "[^:]*_" + last + ")";
    s += "|";
    s += "(" + last + "[^:]*_" + first + ")";
    s += ")";
    regex_parts.push(s);
  }

  /* Allow "tgm" to match "tagme".  If top_results_only is set, we only want primary results,
   * so omit this match. */
  if(!options.top_results_only)
  {
    var s = "(";
    letters.each(function(letter) {
      var escaped_letter = RegExp.escape(letter);
      s += escaped_letter;
      s += '[^:]*';
    });
    s += ")";
    regex_parts.push(s);
  }

  /* The space is included in the result, so the result tags can be matched with the
   * same regexes, for in reorder_search_results. 
   *
   * (\d)+  match the alias ID                      1:
   * [^ ]*: start at the beginning of any alias     1:foo:bar:
   * ... match ...
   * [^:]*: all matches are prefix matches          1:foo:bar:tagme:
   * [^ ]*  match any remaining aliases             1:foo:bar:tagme:tag_me:
   */
  var regex_string = regex_parts.join("|");
  regex_string = "(\\d+)[^ ]*:(" + regex_string + ")[^:]*:[^ ]* ";

  return new RegExp(regex_string, options.global? "g":"");
}

TagCompletionClass.prototype.retrieve_tag_search = function(re, source, options)
{
  var results = [];
  
  var max_results = 10;
  if(options.max_results != null)
    max_results = options.max_results;

  while(results.length < max_results)
  {
    var m = re.exec(source);
    if(!m)
      break;

    var tag = m[0];
    /* Ignore this tag.  We need a better way to blackhole tags. */
    if(tag.indexOf(":deletethistag:") != -1)
      continue;
    if(results.indexOf(tag) == -1)
      results.push(tag);
  }
  return results;
}


/* Mark a tag as recently used.  Recently used tags are matched before other tags. */
TagCompletionClass.prototype.add_recent_tag = function(tag)
{
  /* Don't add tags that will make the data unparsable. */
  if(tag.indexOf(" ") != -1 || tag.indexOf(":") != -1)
    throw "Invalid recent tag: " + tag;

  /* Remove the tag from the recent tag list if it's already there. */
  var escaped_tag = RegExp.escape(tag);
  var re = new RegExp("\\d:" + escaped_tag + ": ");
  this.recent_tags = this.recent_tags.replace(re, "");

  /* Look up the tag type if we know it. */
  var tag_type = Post.tag_types.get(tag) || "general";
  var tag_type_idx = Post.tag_type_names.indexOf(tag_type);

  /* We should know all tag types. */
  if(tag_type_idx == -1)
    throw "Unknown tag type: " + tag_type;

  /* Add the tag to the front.  Always append a space, not just between entries. */
  var tag_entry = tag_type_idx + ":" + tag + ": ";
  this.recent_tags = tag_entry + this.recent_tags;

  /* If the recent tags list is too big, remove data from the end. */
  var max_recent_tags_size = 1024*16;
  if(this.recent_tags.length > max_recent_tags_size * 10/9)
  {
    /* Be sure to leave the trailing space in place. */
    var purge_at = this.recent_tags.indexOf(" ", max_recent_tags_size);
    if(purge_at != -1)
      this.recent_tags = this.recent_tags.slice(0, purge_at+1);
  }

  localStorage.recent_tags = this.recent_tags;
}

/* Add as recent tags all tags which are in tags and not in old_tags. */
TagCompletionClass.prototype.add_recent_tags_from_update = function(tags, old_tags)
{
  tags = tags.split(" ");
  old_tags = old_tags.split(" ");

  tags.each(function(tag) {
    /* Ignore metatags. */
    if(tag.indexOf(":") != -1)
      return;
    /* Ignore rating shortcuts. */
    if("sqe".indexOf(tag) != -1)
      return;
    if(old_tags.indexOf(tag) != -1)
      return;

    this.add_recent_tag(tag);
  }.bind(this));
}

/*
 * Contents matches (t*g*m -> tagme) are lower priority than other results.  Within
 * each search type (recent and main), sort them to the bottom.
 */
TagCompletionClass.prototype.reorder_search_results = function(tag, results)
{
  var re = this.create_tag_search_regex(tag, { top_results_only: true, global: false });
  var top_results = [];
  var bottom_results = [];

  results.each(function(tag) {
    if(re.test(tag))
      top_results.push(tag);
    else
      bottom_results.push(tag);
  });
  return top_results.concat(bottom_results);
}

/*
 * Return an array of completions for a tag.  Tag types of returned tags will be
 * registered in Post.tag_types, if necessary.
 *
 * options = {
 *   max_results: 10
 * }
 */
TagCompletionClass.prototype.complete_tag = function(tag, options)
{
  if(this.tag_data == null)
    throw "Tag data isn't loaded";

  if(options == null)
    options = {};

  if(tag == "")
    return [];

  /* Make a list of all results; this will be ordered recent tags first, other tags
   * sorted by tag count.  Request more results than we need, since we'll reorder
   * them below before cutting it off. */
  var re = this.create_tag_search_regex(tag, { global: true });
  var recent_results = this.retrieve_tag_search(re, this.recent_tags, {max_results: 100});
  var main_results = this.retrieve_tag_search(re, this.tag_data, {max_results: 100});

  recent_results = this.reorder_search_results(tag, recent_results);
  main_results = this.reorder_search_results(tag, main_results);

  var results = recent_results.concat(main_results);

  /* Hack: if the search is one of the ratings shortcuts, put that at the top, even though
   * it's not a real tag. */
  if("sqe".indexOf(tag) != -1)
    results.unshift("0:" + tag + " ");

  results = results.slice(0, options.max_results != null? options.max_results:10);

  /* Strip the "1:" tag type prefix off of each result. */
  var final_results = [];
  var tag_types = {};
  results.each(function(tag) {
    var m = tag.match(/(\d+):([^:]*):[^ ]* /);
    if(!m)
    {
      ReportError("Unparsable cached tag: '" + tag + "'", null, null, null, null);
      throw "Unparsable cached tag: '" + tag + "'";
    }

    var tag = m[2];
    var tag_type = Post.tag_type_names[m[1]];
    tag_types[tag] = tag_type;

    if(final_results.indexOf(tag) == -1)
      final_results.push(tag);
  });

  /* Register tag types of results with Post. */
  Post.register_tags(tag_types, true);

  return final_results;
}

/* This is only supported if the browser supports localStorage.  Also disable this if
 * addEventListener is missing; IE has various problems that aren't worth fixing. */
if(!LocalStorageDisabled() && "addEventListener" in document)
  TagCompletion = new TagCompletionClass();
else
  TagCompletion = null;

TagCompletionBox = function(input_field)
{
  this.input_field = input_field;
  this.update = this.update.bind(this);
  this.last_value = this.input_field.value;

  /* Disable browser autocomplete. */
  this.input_field.setAttribute("autocomplete", "off");

  var html = '<div class="tag-completion-box"><ul class="color-tag-types"></ul></div>';
  var div = html.createElement();
  div.tabindex = -1;
  document.body.appendChild(div);
  this.completion_box = div;

  document.on("mousedown", function(event) {
    if(event.target.isParentNode(this.input_field) || event.target.isParentNode(this.completion_box))
      return;
    this.hide();
  }.bindAsEventListener(this));

  this.input_field.on("mousedown", this.input_mouse.bindAsEventListener(this));
  this.input_field.on("mouseup", this.input_mouse.bindAsEventListener(this));
  this.input_field.parentNode.addEventListener("keydown", this.input_keydown.bindAsEventListener(this), true); // need to use addEventListener for this since Prototype is broken
  this.input_field.on("keypress", this.input_keypress.bindAsEventListener(this));

  this.completion_box.on("mouseover", ".completed-tag", function(event, element) {
    this.focus_element(element);
  }.bind(this));

  this.completion_box.on("click", "li", this.click_result.bind(this));
}

TagCompletionBox.prototype.input_mouse = function(event)
{
  this.update.defer();
}

TagCompletionBox.prototype.input_keydown = function(event)
{
  if(event.target != this.input_field)
    return;

  if(!this.shown)
  {
    this.update.defer();
    return;
  }

  if(event.keyCode == Event.KEY_DOWN)
  {
    event.stop();
    this.select_next(true);
  }
  else if(event.keyCode == Event.KEY_UP)
  {
    event.stop();
    this.select_next(false);
  }
  else if(event.keyCode == Event.KEY_ESC)
  {
    event.stop();
    this.hide();
  }
  else if(event.keyCode == Event.KEY_RETURN)
  {
    var focused = this.completion_box.down(".focused");
    if(focused)
    {
      event.stop();
      this.set_current_word(focused.result_tag);
    }
    else
      this.hide();
  }
  else
  {
    this.update.defer();
  }
}

TagCompletionBox.prototype.focus_element = function(element)
{
  if(element == null)
    throw "Can't select no element";

  var previous = this.completion_box.down(".focused");
  if(previous)
    previous.removeClassName("focused");
  if(element)
    element.addClassName("focused");
}

TagCompletionBox.prototype.select_next = function(next)
{
  var focused = this.completion_box.down(".focused");
  var siblings = next? focused.nextSiblings(): focused.previousSiblings();
  var new_focus = Prototype.Selector.find(siblings, ".completed-tag", 0);
  if(new_focus == null)
    new_focus = this.completion_box.down(next? ".completed-tag":".completed-tag:last-child");

  this.focus_element(new_focus);
}


TagCompletionBox.prototype.show = function()
{
  this.shown = true;
  var offset = this.input_field.cumulativeOffset();
  this.completion_box.style.top = (offset.top + this.input_field.offsetHeight) + "px";
  this.completion_box.style.left = offset.left + "px";
  this.completion_box.style.minWidth = this.input_field.offsetWidth + "px";
}


TagCompletionBox.prototype.hide = function()
{
  this.shown = false;
  this.current_tag = null;
  this.completion_box.hide();
}

TagCompletionBox.prototype.click_result = function(event, element)
{
  event.stop();
  this.set_current_word(element.result_tag);
}

TagCompletionBox.prototype.get_input_word_offset = function(field)
{
  var text = field.value;
  var start_idx = text.lastIndexOf(" ", field.selectionStart-1);
  if(start_idx == -1)
    start_idx = 0;
  else
    ++start_idx; // skip the space itself

  var end_idx = text.indexOf(" ", field.selectionStart);
  if(end_idx == -1)
    end_idx = text.length;

  return {
    start: start_idx,
    end: end_idx
  };
}

/* Replace the tag under the cursor. */
TagCompletionBox.prototype.set_current_word = function(tag)
{
  var offset = this.get_input_word_offset(this.input_field);
  var text = this.input_field.value;
  var before = text.substr(0, offset.start);
  var after = text.substr(offset.end);
  var tag_text = tag;

  /* If there's only whitespace after the tag, remove it.  We'll add a single space
   * below. */
  if(after.match(/^ +$/))
    after = "";

  /* If we're at the end of the string, or if there's only whitespace after the tag,
   * insert a space after the tag. */
  if(after == "")
    tag_text += " ";

  this.input_field.value = before + tag_text + after;
  
  /* Position the cursor at the end of the tag we just inserted. */
  var cursor_position = before.length + tag_text.length;
  this.input_field.selectionStart = this.input_field.selectionEnd = cursor_position;

  TagCompletion.add_recent_tag(tag);

  this.hide();
}

TagCompletionBox.prototype.update = function()
{
  /* If the tag data hasn't been loaded, run the load and rerun the update when it
   * completes. */
  if(!TagCompletion.loaded)
  {
    TagCompletion.load_data(function() {
      this.update();
    }.bind(this));
    return;
  }

  /* Don't show the autocomplete unless the contents actually change, so we can still
   * navigate multiline tag input boxes with the arrow keys. */
  if(this.last_value == this.input_field.value)
    return;
  this.last_value = this.input_field.value;

  /* Figure out the tag the cursor is on. */
  var offset = this.get_input_word_offset(this.input_field);
  var tag = this.input_field.value.substr(offset.start, offset.end-offset.start);

  if(tag == this.current_tag)
    return;

  this.hide();

  this.current_tag = tag;

  /* Don't display if the input field itself is hidden. */
  if(!this.input_field.recursivelyVisible())
    return;

  var tags = TagCompletion.complete_tag(tag);
  if(tags.length == 0)
    return;

  if(tags.length == 1 && tags[0] == tag)
  {
    /* There's only one result, and it's the tag already in the field; don't
     * show the list. */
    return;
  }

  this.show();

  /* Clear any old results. */
  var ul = this.completion_box.down("UL");
  this.completion_box.hide();
  while(ul.firstChild)
    ul.removeChild(ul.firstChild);

  tags.each(function(tag) {
    var li = document.createElement("LI");
    li.className = "completed-tag";
    li.setTextContent(tag);
    ul.appendChild(li);

    var tag_type = Post.tag_types.get(tag);
    li.className += " tag-type-" + tag_type;
    li.result_tag = tag;
  });

  this.completion_box.show();

  /* Focus the first item. */
  this.focus_element(this.completion_box.down(".completed-tag"));
}

TagCompletionBox.prototype.input_keypress = function(event)
{
  this.update.defer();
}

/* If tag completion isn't supported, disable TagCompletionBox. */
if(TagCompletion == null || !("addEventListener" in document))
  TagCompletionBox = function() {};

