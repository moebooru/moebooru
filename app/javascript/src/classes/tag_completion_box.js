/* globals Post, Prototype, TagCompletion */
import { isVisible, stringToDom } from 'src/utils/dom';

function createCompletionBox () {
  const ret = document.createElement('div');
  ret.className = 'tag-completion-box';
  ret.tabIndex = -1;

  const types = document.createElement('ul');
  types.className = 'color-tag-types';

  ret.appendChild(types);

  return ret;
}

export default class TagCompletionBox {
  constructor (inputField) {
    // Replace the tag under the cursor.
    this.input_field = inputField;
    this.last_value = this.input_field.value;
    // Disable browser autocomplete.
    this.input_field.setAttribute('autocomplete', 'off');
    this.completion_box = createCompletionBox();
    document.body.appendChild(this.completion_box);
    document.on('mousedown', (event) => {
      if (this.input_field.contains(event.target) || this.completion_box.contains(event.target)) {
        return;
      }
      this.hide();
    });
    this.input_field.on('mousedown', this.input_mouse);
    this.input_field.on('mouseup', this.input_mouse);
    this.input_field.parentNode.addEventListener('keydown', this.input_keydown, true);
    // need to use addEventListener for this since Prototype is broken
    this.completion_box.on('mouseover', '.completed-tag', (event, element) => {
      this.focus_element(element);
    });
    this.completion_box.on('click', 'li', this.click_result);
    this.hide();
  }

  input_mouse = (event) => {
    this.update.defer();
  };

  input_keydown = (event) => {
    if (event.target !== this.input_field) {
      return;
    }
    // Handle backspaces even when hidden.
    if (event.keyCode === Event.KEY_BACKSPACE) {
      /**
       * If the user holds down backspace to delete tags, don't spend time updating the
       * autocomplete; if it's too slow it may slow down the input.  However, we don't
       * want to always delay autocomplete on backspace; it looks unresponsive.
       *
       * Count the number of backspaces we receive less than 100ms apart.  Defer updates
       * after we receive two or more in rapid succession, so we'll defer when backspace
       * is held down but not when being depressed.
       *
       * Note that this is done this way rather than by tracking the pressed state with
       * keydown/keyup, because this way we don't need to deal with lost keyup events if
       * focus is lost while the key is pressed.  There's no way to become desynced this way.
       */
      ++this.rapid_backspaces_received;
      clearTimeout(this.backspace_timeout);
      this.backspace_timeout = setTimeout(() => {
        this.rapid_backspaces_received = 0;
      }, 100);
      if (this.rapid_backspaces_received > 1) {
        this.updates_deferred = true;
        clearTimeout(this.defer_timeout);
        this.defer_timeout = setTimeout(() => {
          this.updates_deferred = false;
          this.update();
        }, 100);
      }
    }
    if (!this.shown) {
      this.update.defer();
      return;
    }
    if (event.keyCode === Event.KEY_DOWN) {
      event.stop();
      this.select_next(true);
    } else if (event.keyCode === Event.KEY_UP) {
      event.stop();
      this.select_next(false);
    } else if (event.keyCode === Event.KEY_ESC) {
      event.stop();
      this.hide();
    } else if (event.keyCode === Event.KEY_RETURN) {
      const focused = this.completion_box.down('.focused');
      if (focused) {
        event.stop();
        this.set_current_word(focused.result_tag);
      } else {
        this.hide();
      }
    } else {
      this.update.defer();
    }
  };

  focus_element = (element) => {
    if (element == null) {
      throw new Error('Can\'t select no element');
    }
    const previous = this.completion_box.down('.focused');
    if (previous) {
      previous.removeClassName('focused');
    }
    if (element) {
      element.addClassName('focused');
    }
  };

  select_next = (next) => {
    const focused = this.completion_box.down('.focused');
    const siblings = next ? focused.nextSiblings() : focused.previousSiblings();
    const newFocus = Prototype.Selector.find(siblings, '.completed-tag', 0) ??
      this.completion_box.down(next ? '.completed-tag' : '.completed-tag:last-child');
    this.focus_element(newFocus);
  };

  show () {
    this.shown = true;
    const offset = this.input_field.cumulativeOffset();
    this.completion_box.style.top = offset.top + this.input_field.offsetHeight + 'px';
    this.completion_box.style.left = offset.left + 'px';
    this.completion_box.style.minWidth = this.input_field.offsetWidth + 'px';
  }

  hide () {
    this.shown = false;
    this.current_tag = null;
    this.completion_box.hide();
  }

  click_result = (event, element) => {
    event.stop();
    if (event.target.hasClassName('remove-recent-tag')) {
      TagCompletion.remove_recent_tag(element.result_tag);
      this.update(true);
      return;
    }
    this.set_current_word(element.result_tag);
  };

  get_input_word_offset (field) {
    const text = field.value;
    let startIdx = text.lastIndexOf(' ', field.selectionStart - 1);
    if (startIdx === -1) {
      startIdx = 0;
    } else {
      ++startIdx;
    }
    // skip the space itself
    let endIdx = text.indexOf(' ', field.selectionStart);
    if (endIdx === -1) {
      endIdx = text.length;
    }
    return {
      start: startIdx,
      end: endIdx
    };
  }

  set_current_word (tag) {
    const offset = this.get_input_word_offset(this.input_field);
    const text = this.input_field.value;
    const before = text.substr(0, offset.start);
    let after = text.substr(offset.end);
    let tagText = tag;
    // If there's only whitespace after the tag, remove it.  We'll add a single space
    // below.
    if (after.match(/^ +$/)) {
      after = '';
    }
    // If we're at the end of the string, or if there's only whitespace after the tag,
    // insert a space after the tag.
    if (after === '') {
      tagText += ' ';
    }
    this.input_field.value = before + tagText + after;
    // Position the cursor at the end of the tag we just inserted.
    const cursorPosition = before.length + tagText.length;
    this.input_field.selectionStart = this.input_field.selectionEnd = cursorPosition;
    TagCompletion.add_recent_tag(tag);
    this.hide();
  }

  update = (force) => {
    if (this.updates_deferred && !force) {
      return;
    }
    if (TagCompletion.tag_data == null) {
      // If this returns true, we'll display with the data we have now.  If this happens,
      // don't update during the callback; it's bad UI to be changing the list out from
      // under the user at a seemingly random time.
      const dataAvailable = TagCompletion.load_data(() => {
        if (dataAvailable) {
          return;
        }
        // After the load completes, force an update, even though the tag we're completing
        // hasn't changed; the tag data may have.
        this.current_tag = null;
        this.update();
      });
      if (!dataAvailable) {
        return;
      }
    }
    // Figure out the tag the cursor is on.
    const offset = this.get_input_word_offset(this.input_field);
    const tag = this.input_field.value.substr(offset.start, offset.end - offset.start);
    if (tag === this.current_tag && !force) {
      return;
    }
    this.hide();
    // Don't show the autocomplete unless the contents actually change, so we can still
    // navigate multiline tag input boxes with the arrow keys.
    if (this.last_value === this.input_field.value && !force) {
      return;
    }
    this.last_value = this.input_field.value;
    this.current_tag = tag;
    if (!isVisible(this.input_field)) {
      return;
    }
    const tagsAndRecentCount = TagCompletion.complete_tag(tag);
    const tags = tagsAndRecentCount[0];
    const tagAliases = tagsAndRecentCount[2];
    const recentResultCount = tagsAndRecentCount[1];
    if (tags.length === 0) {
      return;
    }
    if (tags.length === 1 && tags[0] === tag) {
      return;
    }
    // There's only one result, and it's the tag already in the field; don't
    // show the list.
    this.show();
    // Clear any old results.
    const ul = this.completion_box.down('UL');
    this.completion_box.hide();
    while (ul.firstChild) {
      ul.removeChild(ul.firstChild);
    }
    // TODO: use tags.entries() after removing prototype
    for (let i = 0; i < tags.length; i++) {
      const tag = tags[i];
      const li = document.createElement('LI');
      li.className = 'completed-tag';
      li.textContent = tag;
      ul.appendChild(li);
      // If we have any aliases, show the first one.
      const aliases = tagAliases[i];
      if (aliases.length > 0) {
        const span = document.createElement('span');
        span.className = 'completed-tag-alias';
        span.textContent = aliases[0];
        li.appendChild(span);
      }
      const tagType = Post.tag_types.get(tag);
      li.className += ' tag-type-' + tagType;
      if (i < recentResultCount) {
        li.className += ' recent-tag';
        const h = '<a class=\'remove-recent-tag\' href=\'#\'>X</a>\'';
        li.appendChild(stringToDom(h));
      }
      li.result_tag = tag;
    }
    this.completion_box.show();
    // Focus the first item.
    this.focus_element(this.completion_box.down('.completed-tag'));
  };
}
