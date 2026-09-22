/* globals jQuery, Post */
// From a tag string, eg. "1`tagme`alias`alias2`", retrieve the tag name "tagme".
function getTagFromString (tagString) {
  const m = tagString.match(/\d+`([^`]*)`.*/);
  if (m == null) {
    throw new Error(`Unparsable cached tag: '${tagString}'`);
  }
  return m[1];
}

/**
 * Like string.split, but rather than each item of data being separated by the separator,
 * each item of data ends in the separator; that is, the final item is followed by the
 * separator.
 *
 * "a b c " -> ["a", "b", "c"].
 *
 * If the final item doesn't end in the separator, throw an exception.
 */
function splitData (str, separator) {
  const result = str.split(separator);

  if (result.length !== 0) {
    const resultEnd = result.pop();
    if (resultEnd !== '') {
      throw new Error("String doesn't end in separator");
    }
  }

  return result;
}

function joinData (items, separator) {
  return items.length === 0
    ? ''
    : `${items.join(separator)}${separator}`;
}

/**
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
 * ':[^ ]*me ' - suffix match
 * ':[^ ]*t[^ ]*g[^ ]*m' - ordered character match
 */
export default class TagCompletion {
  constructor () {
    // Don't load the tag data out of localStorage until it's needed.
    this.loading = false;
    this.loaded = false;
    // If the data format is out of date, clear it.
    const currentVersion = '5';
    if (window.localStorage.tag_data_format !== currentVersion) {
      delete window.localStorage.tag_data;
      delete window.localStorage.tag_data_version;
      delete window.localStorage.recent_tags;
      window.localStorage.tag_data_format = currentVersion;
    }
    // Pull in recent tags.  This is entirely local data and not too big, so always load it.
    this.recent_tags = window.localStorage.recent_tags || '';
    this.load_data_complete_callbacks = [];
    this.rapid_backspaces_received = 0;
    this.updates_deferred = false;
  }

  init = (currentVersion) => {
    if (this.loaded) return;

    this.most_recent_tag_data_version = currentVersion;
  };

  /**
   * If cached data is available, load it.  If the cached data is out of date, run an
   * update asynchronously.  Return true if data is available and tag completions may
   * be done, whether or not the data is current.  Call onComplete when up-to-date tag
   * data is available; if the current cached data is known to be current, it will be
   * called before this function returns.
   *
   * If this is called multiple times before the tag load completes, the data will only be loaded
   * once, but all callbacks will be called.
   */
  load_data = (onComplete) => {
    // If we're already fully loaded, just run the callback and return.
    if (this.loaded) {
      if (typeof onComplete === 'function') {
        onComplete();
      }
      return this.tag_data != null;
    }
    // Add the callback to the list.
    if (onComplete != null) {
      this.load_data_complete_callbacks.push(onComplete);
    }
    // If we're already loading, let the existing request finish; it'll run the callback.
    if (this.loading) {
      return this.tag_data != null;
    }
    this.loading = true;
    const complete = () => {
      this.loading = false;
      this.loaded = true;
      // Now that we have the tag types loaded, update any tag types that we have loaded.
      this.update_tag_types();
      const callbacks = this.load_data_complete_callbacks;
      this.load_data_complete_callbacks = [];

      for (const callback of callbacks) {
        callback();
      }
    };
    // If we have data available, load it.
    if (window.localStorage.tag_data != null) {
      this.tag_data = window.localStorage.tag_data;
      if (this.most_recent_tag_data_version == null || window.localStorage.tag_data_version === this.most_recent_tag_data_version) {
        // console.log("Already on most recent tag data version");
        complete();
        return this.tag_data != null;
      }
    }
    // Request the tag data from the server.  Tell the server the data version we already
    // have.
    jQuery.ajax({
      url: '/tag/summary.json',
      data: {
        version: window.localStorage.tag_data_version
      },
      dataType: 'json'
    }).done((json) => {
      if (json.unchanged) {
        // If unchanged is true, tag_data_version is already current; this means we weren't told
        // the current data revision to start with but we're already up to date.
        // console.log("Tag data unchanged")
        this.tag_data = window.localStorage.tag_data;
      } else {
        // We received new tag data; save it.
        // console.log("Storing new tag data")
        this.tag_data = json.data;
        window.localStorage.tag_data = this.tag_data;
        window.localStorage.tag_data_version = json.version;
      }
      complete();
    });
    return this.tag_data != null;
  };

  // When form is submitted, call add_recent_tags_from_update for the given tags and old_tags
  // fields.
  observe_tag_changes_on_submit = (form, tagsField, oldTagsField) => {
    form.on('submit', (e) => {
      this.add_recent_tags_from_update(tagsField.value, oldTagsField?.value);
    });
  };

  // Update the cached types of all known tags in tag_data and recent_tags.
  update_tag_types_for_list = (tags, allowAdd) => {
    const tagMap = {};
    // Make a mapping of tags to indexes.
    const splitTags = splitData(tags, ' ');
    for (let i = 0; i < splitTags.length; i++) {
      const tag = splitTags[i];
      if (tag === '') continue;

      tagMap[getTagFromString(tag)] = i;
    }

    /**
     * For each known tag type, mark the type in the tag cache.  We receive this info when
     * we download the tag types, so this is just updating any changes.
     *
     * This is set up to iterate only over known types, and not over the entire list of
     * tags, so when we have a lot of tags we minimize the amount of work we have to do
     * on every tag.
     */
    Post.tag_types.each((tagAndType) => {
      const [tag, tagType] = tagAndType;
      const tagTypeIdx = Post.tag_type_names.indexOf(tagType);
      if (tagTypeIdx === -1) {
        throw new Error(`Unknown tag type ${tagType}`);
      }
      if (tagMap[tag] == null) {
        // This tag is known in Post.tag_types, but isn't a known tag.  If allowAdd is true,
        // add it to the end.  This is for updating new tags that have shown up on the server,
        // not for adding new recent tags.
        if (allowAdd) {
          splitTags.push(`${tagTypeIdx}\`${tag}\``);
        }
      } else {
        // This is a known tag; this is the usual case.  Parse out the complete tag from the
        // original string, and update the tag type index.
        const tagIdx = tagMap[tag];
        const existingTag = splitTags[tagIdx];
        const m = existingTag.match(/\d+(`.*)/);
        splitTags[tagIdx] = `${tagTypeIdx}${m[1]}`;
      }
    });

    return joinData(splitTags, ' ');
  };

  update_tag_types = () => {
    if (!this.loaded) return;

    // Update both tag_data and recent_tags; only add new entries to tag_data.
    this.tag_data = this.update_tag_types_for_list(this.tag_data, true);
    window.localStorage.tag_data = this.tag_data;
    this.recent_tags = this.update_tag_types_for_list(this.recent_tags, false);
    window.localStorage.recent_tags = this.recent_tags;
  };

  create_tag_search_regex = (tag, options) => {
    // Split the tag by character.
    const letters = tag.split('');
    /**
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
    const regexParts = [];

    /**
     * Allow basic word prefix matches.  "tag" matches at the beginning of any word
     * in a tag, eg. both "tagme" and "dont_tagme".
     *
     * Add the regex for ordinary prefix matches.
     */
    let s = '(([^`]*_)?';
    letters.each(function (letter) {
      s += RegExp.escape(letter);
    });
    s += ')';
    regexParts.push(s);
    // Allow "fir_las" to match both "first_last" and "last_first".
    if (tag.indexOf('_') !== -1) {
      let first = tag.split('_', 1)[0];
      let last = tag.slice(first.length + 1);
      first = RegExp.escape(first);
      last = RegExp.escape(last);
      s = '(';
      s += '(' + first + '[^`]*_' + last + ')';
      s += '|';
      s += '(' + last + '[^`]*_' + first + ')';
      s += ')';
      regexParts.push(s);
    }
    if (!options.top_results_only && letters.length < 12) {
      s = '(';
      letters.each(function (letter) {
        s += RegExp.escape(letter);
        s += '[^`]*';
      });
      s += ')';
      regexParts.push(s);
    }
    // The space is included in the result, so the result tags can be matched with the
    // same regexes, for in reorder_search_results.

    // (\d)+  match the alias ID                      1`
    // [^ ]*: start at the beginning of any alias     1`foo`bar`
    // ... match ...
    // [^`]*` all matches are prefix matches          1`foo`bar`tagme`
    // [^ ]*  match any remaining aliases             1`foo`bar`tagme`tag_me`
    let regexString = regexParts.join('|');
    regexString = '(\\d+)[^ ]*`(' + regexString + ')[^`]*`[^ ]* ';
    return new RegExp(regexString, options.global ? 'g' : '');
  };

  retrieve_tag_search = (re, source, options) => {
    const results = [];
    let maxResults = 10;
    if (options.max_results != null) {
      maxResults = options.max_results;
    }
    while (results.length < maxResults) {
      const m = re.exec(source);
      if (!m) {
        break;
      }
      const tag = m[0];
      // Ignore this tag.  We need a better way to blackhole tags.
      if (tag.indexOf(':deletethistag:') !== -1) {
        continue;
      }
      if (results.indexOf(tag) === -1) {
        results.push(tag);
      }
    }
    return results;
  };

  // Mark a tag as recently used.  Recently used tags are matched before other tags.
  add_recent_tag = (tag) => {
    // Don't add tags that will make the data unparsable.
    if (tag.indexOf(' ') !== -1 || tag.indexOf('`') !== -1) {
      throw new Error(`Invalid recent tag: ${tag}`);
    }
    this.remove_recent_tag(tag);
    // Look up the tag type if we know it.
    const tagType = Post.tag_types.get(tag) || 'general';
    const tagTypeIdx = Post.tag_type_names.indexOf(tagType);
    // We should know all tag types.
    if (tagTypeIdx === -1) {
      throw new Error(`Unknown tag type: ${tagType}`);
    }
    // Add the tag to the front.  Always append a space, not just between entries.
    const tagEntry = tagTypeIdx + '`' + tag + '` ';
    this.recent_tags = tagEntry + this.recent_tags;
    // If the recent tags list is too big, remove data from the end.
    const maxRecentTagsSize = 1024 * 16;
    if (this.recent_tags.length > maxRecentTagsSize * 10 / 9) {
      // Be sure to leave the trailing space in place.
      const purgeAt = this.recent_tags.indexOf(' ', maxRecentTagsSize);
      if (purgeAt !== -1) {
        this.recent_tags = this.recent_tags.slice(0, purgeAt + 1);
      }
    }
    window.localStorage.recent_tags = this.recent_tags;
  };

  // Remove the tag from the recent tag list.
  remove_recent_tag = (tag) => {
    const escapedTag = RegExp.escape(tag);
    const re = new RegExp('\\d`' + escapedTag + '` ', 'g');
    this.recent_tags = this.recent_tags.replace(re, '');
    window.localStorage.recent_tags = this.recent_tags;
  };

  // Add as recent tags all tags which are in tags and not in old_tags.  If this is from an
  // edit form, old_tags must be the hidden old_tags value in the edit form; if this is
  // from a search form, old_tags must be null.
  add_recent_tags_from_update = (tags, oldTags) => {
    tags = tags.split(' ');
    if (oldTags != null) {
      oldTags = oldTags.split(' ');
    }
    for (const tag of tags) {
      // Ignore invalid tags.
      if (tag.indexOf('`') !== -1) {
        continue;
      }
      // Ignore rating shortcuts.
      if ('sqe'.indexOf(tag) !== -1) {
        continue;
      }
      // Ignore tags that the user didn't just add.
      if (oldTags && oldTags.indexOf(tag) !== -1) {
        continue;
      }
      if ((oldTags == null) && tag.indexOf(':') === -1) {
        if (this.tag_data.indexOf('`' + tag + '`') === -1) {
          continue;
        }
      }
      this.add_recent_tag(tag);
    }
  };

  // Contents matches (t*g*m -> tagme) are lower priority than other results.  Within
  // each search type (recent and main), sort them to the bottom.
  reorder_search_results = (tag, results) => {
    const re = this.create_tag_search_regex(tag, {
      top_results_only: true,
      global: false
    });
    const topResults = [];
    const bottomResults = [];
    results.each(function (tag) {
      if (re.test(tag)) {
        topResults.push(tag);
      } else {
        bottomResults.push(tag);
      }
    });
    return topResults.concat(bottomResults);
  };

  /**
   * Return an array of completions for a tag.  Tag types of returned tags will be
   * registered in Post.tag_types, if necessary.
   *
   * options = {
   *   max_results: 10
   * }
   *
   * [["tag1", "tag2", "tag3"], 1]
   *
   * The value 1 is the number of results from the beginning which come from recent_tags,
   * rather than tag_data.
   */
  complete_tag = (tag, options) => {
    if (this.tag_data == null) {
      throw new Error("Tag data isn't loaded");
    }
    if (options == null) {
      options = {};
    }
    if (tag === '') {
      return [[], 0];
    }
    // Make a list of all results; this will be ordered recent tags first, other tags
    // sorted by tag count.  Request more results than we need, since we'll reorder
    // them below before cutting it off.
    const re = this.create_tag_search_regex(tag, {
      global: true
    });
    let recentResults = this.retrieve_tag_search(re, this.recent_tags, {
      max_results: 100
    });
    let mainResults = this.retrieve_tag_search(re, this.tag_data, {
      max_results: 100
    });
    recentResults = this.reorder_search_results(tag, recentResults);
    mainResults = this.reorder_search_results(tag, mainResults);
    let recentResultCount = recentResults.length;
    let results = recentResults.concat(mainResults);
    // Hack: if the search is one of the ratings shortcuts, put that at the top, even though
    // it's not a real tag.
    if ('sqe'.indexOf(tag) !== -1) {
      results.unshift('0`' + tag + '` ');
    }
    results = results.slice(0, options.max_results != null ? options.max_results : 10);
    recentResultCount = Math.min(results.length, recentResultCount);
    // Strip the "1`" tag type prefix off of each result.
    const finalResults = [];
    const tagTypes = {};
    const finalAliases = [];
    results.each(function (tag) {
      const m = tag.match(/(\d+)`([^`]*)`(([^ ]*)`)? /);
      if (!m) {
        throw new Error(`Unparsable cached tag: '${tag}'`);
      }
      tag = m[2];
      const tagType = Post.tag_type_names[m[1]];
      let aliases = m[4];
      if (m[4]) {
        aliases = aliases.split('`');
      } else {
        aliases = [];
      }
      tagTypes[tag] = tagType;
      if (finalResults.indexOf(tag) === -1) {
        finalResults.push(tag);
        finalAliases.push(aliases);
      }
    });
    // Register tag types of results with Post.
    Post.register_tags(tagTypes, true);
    return [finalResults, recentResultCount, finalAliases];
  };
}
