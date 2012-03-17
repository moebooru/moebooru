/*  Prototype JavaScript framework, version 1.7
 *  (c) 2005-2010 Sam Stephenson
 *
 *  Prototype is freely distributable under the terms of an MIT-style license.
 *  For details, see the Prototype web site: http://www.prototypejs.org/
 *
 *--------------------------------------------------------------------------*/

var Prototype = {

  Version: '1.7',

  Browser: (function(){
    var ua = navigator.userAgent;
    var isOpera = Object.prototype.toString.call(window.opera) == '[object Opera]';
    return {
      IE:             !!window.attachEvent && !isOpera,
      Opera:          isOpera,
      WebKit:         ua.indexOf('AppleWebKit/') > -1,
      Gecko:          ua.indexOf('Gecko') > -1 && ua.indexOf('KHTML') === -1,
      MobileSafari:   /Apple.*Mobile/.test(ua)
    }
  })(),

  BrowserFeatures: {
    XPath: !!document.evaluate,

    SelectorsAPI: !!document.querySelector,

    ElementExtensions: (function() {
      var constructor = window.Element || window.HTMLElement;
      return !!(constructor && constructor.prototype);
    })(),
    SpecificElementExtensions: (function() {
      if (typeof window.HTMLDivElement !== 'undefined')
        return true;

      var div = document.createElement('div'),
          form = document.createElement('form'),
          isSupported = false;

      if (div['__proto__'] && (div['__proto__'] !== form['__proto__'])) {
        isSupported = true;
      }

      div = form = null;

      return isSupported;
    })()
  },

  ScriptFragment: '<script[^>]*>([\\S\\s]*?)<\/script>',
  JSONFilter: /^\/\*-secure-([\s\S]*)\*\/\s*$/,

  emptyFunction: function() { },

  K: function(x) { return x }
};

if (Prototype.Browser.MobileSafari)
  Prototype.BrowserFeatures.SpecificElementExtensions = false;


var Abstract = { };


var Try = {
  these: function() {
    var returnValue;

    for (var i = 0, length = arguments.length; i < length; i++) {
      var lambda = arguments[i];
      try {
        returnValue = lambda();
        break;
      } catch (e) { }
    }

    return returnValue;
  }
};

/* Based on Alex Arnell's inheritance implementation. */

var Class = (function() {

  var IS_DONTENUM_BUGGY = (function(){
    for (var p in { toString: 1 }) {
      if (p === 'toString') return false;
    }
    return true;
  })();

  function subclass() {};
  function create() {
    var parent = null, properties = $A(arguments);
    if (Object.isFunction(properties[0]))
      parent = properties.shift();

    function klass() {
      this.initialize.apply(this, arguments);
    }

    Object.extend(klass, Class.Methods);
    klass.superclass = parent;
    klass.subclasses = [];

    if (parent) {
      subclass.prototype = parent.prototype;
      klass.prototype = new subclass;
      parent.subclasses.push(klass);
    }

    for (var i = 0, length = properties.length; i < length; i++)
      klass.addMethods(properties[i]);

    if (!klass.prototype.initialize)
      klass.prototype.initialize = Prototype.emptyFunction;

    klass.prototype.constructor = klass;
    return klass;
  }

  function addMethods(source) {
    var ancestor   = this.superclass && this.superclass.prototype,
        properties = Object.keys(source);

    if (IS_DONTENUM_BUGGY) {
      if (source.toString != Object.prototype.toString)
        properties.push("toString");
      if (source.valueOf != Object.prototype.valueOf)
        properties.push("valueOf");
    }

    for (var i = 0, length = properties.length; i < length; i++) {
      var property = properties[i], value = source[property];
      if (ancestor && Object.isFunction(value) &&
          value.argumentNames()[0] == "$super") {
        var method = value;
        value = (function(m) {
          return function() { return ancestor[m].apply(this, arguments); };
        })(property).wrap(method);

        value.valueOf = method.valueOf.bind(method);
        value.toString = method.toString.bind(method);
      }
      this.prototype[property] = value;
    }

    return this;
  }

  return {
    create: create,
    Methods: {
      addMethods: addMethods
    }
  };
})();
(function() {

  var _toString = Object.prototype.toString,
      NULL_TYPE = 'Null',
      UNDEFINED_TYPE = 'Undefined',
      BOOLEAN_TYPE = 'Boolean',
      NUMBER_TYPE = 'Number',
      STRING_TYPE = 'String',
      OBJECT_TYPE = 'Object',
      FUNCTION_CLASS = '[object Function]',
      BOOLEAN_CLASS = '[object Boolean]',
      NUMBER_CLASS = '[object Number]',
      STRING_CLASS = '[object String]',
      ARRAY_CLASS = '[object Array]',
      DATE_CLASS = '[object Date]',
      NATIVE_JSON_STRINGIFY_SUPPORT = window.JSON &&
        typeof JSON.stringify === 'function' &&
        JSON.stringify(0) === '0' &&
        typeof JSON.stringify(Prototype.K) === 'undefined';

  function Type(o) {
    switch(o) {
      case null: return NULL_TYPE;
      case (void 0): return UNDEFINED_TYPE;
    }
    var type = typeof o;
    switch(type) {
      case 'boolean': return BOOLEAN_TYPE;
      case 'number':  return NUMBER_TYPE;
      case 'string':  return STRING_TYPE;
    }
    return OBJECT_TYPE;
  }

  function extend(destination, source) {
    for (var property in source)
      destination[property] = source[property];
    return destination;
  }

  function inspect(object) {
    try {
      if (isUndefined(object)) return 'undefined';
      if (object === null) return 'null';
      return object.inspect ? object.inspect() : String(object);
    } catch (e) {
      if (e instanceof RangeError) return '...';
      throw e;
    }
  }

  function toJSON(value) {
    return Str('', { '': value }, []);
  }

  function Str(key, holder, stack) {
    var value = holder[key],
        type = typeof value;

    if (Type(value) === OBJECT_TYPE && typeof value.toJSON === 'function') {
      value = value.toJSON(key);
    }

    var _class = _toString.call(value);

    switch (_class) {
      case NUMBER_CLASS:
      case BOOLEAN_CLASS:
      case STRING_CLASS:
        value = value.valueOf();
    }

    switch (value) {
      case null: return 'null';
      case true: return 'true';
      case false: return 'false';
    }

    type = typeof value;
    switch (type) {
      case 'string':
        return value.inspect(true);
      case 'number':
        return isFinite(value) ? String(value) : 'null';
      case 'object':

        for (var i = 0, length = stack.length; i < length; i++) {
          if (stack[i] === value) { throw new TypeError(); }
        }
        stack.push(value);

        var partial = [];
        if (_class === ARRAY_CLASS) {
          for (var i = 0, length = value.length; i < length; i++) {
            var str = Str(i, value, stack);
            partial.push(typeof str === 'undefined' ? 'null' : str);
          }
          partial = '[' + partial.join(',') + ']';
        } else {
          var keys = Object.keys(value);
          for (var i = 0, length = keys.length; i < length; i++) {
            var key = keys[i], str = Str(key, value, stack);
            if (typeof str !== "undefined") {
               partial.push(key.inspect(true)+ ':' + str);
             }
          }
          partial = '{' + partial.join(',') + '}';
        }
        stack.pop();
        return partial;
    }
  }

  function stringify(object) {
    return JSON.stringify(object);
  }

  function toQueryString(object) {
    return $H(object).toQueryString();
  }

  function toHTML(object) {
    return object && object.toHTML ? object.toHTML() : String.interpret(object);
  }

  function keys(object) {
    if (Type(object) !== OBJECT_TYPE) { throw new TypeError(); }
    var results = [];
    for (var property in object) {
      if (object.hasOwnProperty(property)) {
        results.push(property);
      }
    }
    return results;
  }

  function values(object) {
    var results = [];
    for (var property in object)
      results.push(object[property]);
    return results;
  }

  function clone(object) {
    return extend({ }, object);
  }

  function isElement(object) {
    return !!(object && object.nodeType == 1);
  }

  function isArray(object) {
    return _toString.call(object) === ARRAY_CLASS;
  }

  var hasNativeIsArray = (typeof Array.isArray == 'function')
    && Array.isArray([]) && !Array.isArray({});

  if (hasNativeIsArray) {
    isArray = Array.isArray;
  }

  function isHash(object) {
    return object instanceof Hash;
  }

  function isFunction(object) {
    return _toString.call(object) === FUNCTION_CLASS;
  }

  function isString(object) {
    return _toString.call(object) === STRING_CLASS;
  }

  function isNumber(object) {
    return _toString.call(object) === NUMBER_CLASS;
  }

  function isDate(object) {
    return _toString.call(object) === DATE_CLASS;
  }

  function isUndefined(object) {
    return typeof object === "undefined";
  }

  extend(Object, {
    extend:        extend,
    inspect:       inspect,
    toJSON:        NATIVE_JSON_STRINGIFY_SUPPORT ? stringify : toJSON,
    toQueryString: toQueryString,
    toHTML:        toHTML,
    keys:          Object.keys || keys,
    values:        values,
    clone:         clone,
    isElement:     isElement,
    isArray:       isArray,
    isHash:        isHash,
    isFunction:    isFunction,
    isString:      isString,
    isNumber:      isNumber,
    isDate:        isDate,
    isUndefined:   isUndefined
  });
})();
Object.extend(Function.prototype, (function() {
  var slice = Array.prototype.slice;

  function update(array, args) {
    var arrayLength = array.length, length = args.length;
    while (length--) array[arrayLength + length] = args[length];
    return array;
  }

  function merge(array, args) {
    array = slice.call(array, 0);
    return update(array, args);
  }

  function argumentNames() {
    var names = this.toString().match(/^[\s\(]*function[^(]*\(([^)]*)\)/)[1]
      .replace(/\/\/.*?[\r\n]|\/\*(?:.|[\r\n])*?\*\//g, '')
      .replace(/\s+/g, '').split(',');
    return names.length == 1 && !names[0] ? [] : names;
  }

  function bind(context) {
    if (arguments.length < 2 && Object.isUndefined(arguments[0])) return this;
    var __method = this, args = slice.call(arguments, 1);
    return function() {
      var a = merge(args, arguments);
      return __method.apply(context, a);
    }
  }

  function bindAsEventListener(context) {
    var __method = this, args = slice.call(arguments, 1);
    return function(event) {
      var a = update([event || window.event], args);
      return __method.apply(context, a);
    }
  }

  function curry() {
    if (!arguments.length) return this;
    var __method = this, args = slice.call(arguments, 0);
    return function() {
      var a = merge(args, arguments);
      return __method.apply(this, a);
    }
  }

  function delay(timeout) {
    var __method = this, args = slice.call(arguments, 1);
    timeout = timeout * 1000;
    return window.setTimeout(function() {
      return __method.apply(__method, args);
    }, timeout);
  }

  function defer() {
    var args = update([0.01], arguments);
    return this.delay.apply(this, args);
  }

  function wrap(wrapper) {
    var __method = this;
    return function() {
      var a = update([__method.bind(this)], arguments);
      return wrapper.apply(this, a);
    }
  }

  function methodize() {
    if (this._methodized) return this._methodized;
    var __method = this;
    return this._methodized = function() {
      var a = update([this], arguments);
      return __method.apply(null, a);
    };
  }

  return {
    argumentNames:       argumentNames,
    bind:                bind,
    bindAsEventListener: bindAsEventListener,
    curry:               curry,
    delay:               delay,
    defer:               defer,
    wrap:                wrap,
    methodize:           methodize
  }
})());



(function(proto) {


  function toISOString() {
    return this.getUTCFullYear() + '-' +
      (this.getUTCMonth() + 1).toPaddedString(2) + '-' +
      this.getUTCDate().toPaddedString(2) + 'T' +
      this.getUTCHours().toPaddedString(2) + ':' +
      this.getUTCMinutes().toPaddedString(2) + ':' +
      this.getUTCSeconds().toPaddedString(2) + 'Z';
  }


  function toJSON() {
    return this.toISOString();
  }

  if (!proto.toISOString) proto.toISOString = toISOString;
  if (!proto.toJSON) proto.toJSON = toJSON;

})(Date.prototype);


RegExp.prototype.match = RegExp.prototype.test;

RegExp.escape = function(str) {
  return String(str).replace(/([.*+?^=!:${}()|[\]\/\\])/g, '\\$1');
};
var PeriodicalExecuter = Class.create({
  initialize: function(callback, frequency) {
    this.callback = callback;
    this.frequency = frequency;
    this.currentlyExecuting = false;

    this.registerCallback();
  },

  registerCallback: function() {
    this.timer = setInterval(this.onTimerEvent.bind(this), this.frequency * 1000);
  },

  execute: function() {
    this.callback(this);
  },

  stop: function() {
    if (!this.timer) return;
    clearInterval(this.timer);
    this.timer = null;
  },

  onTimerEvent: function() {
    if (!this.currentlyExecuting) {
      try {
        this.currentlyExecuting = true;
        this.execute();
        this.currentlyExecuting = false;
      } catch(e) {
        this.currentlyExecuting = false;
        throw e;
      }
    }
  }
});
Object.extend(String, {
  interpret: function(value) {
    return value == null ? '' : String(value);
  },
  specialChar: {
    '\b': '\\b',
    '\t': '\\t',
    '\n': '\\n',
    '\f': '\\f',
    '\r': '\\r',
    '\\': '\\\\'
  }
});

Object.extend(String.prototype, (function() {
  var NATIVE_JSON_PARSE_SUPPORT = window.JSON &&
    typeof JSON.parse === 'function' &&
    JSON.parse('{"test": true}').test;

  function prepareReplacement(replacement) {
    if (Object.isFunction(replacement)) return replacement;
    var template = new Template(replacement);
    return function(match) { return template.evaluate(match) };
  }

  function gsub(pattern, replacement) {
    var result = '', source = this, match;
    replacement = prepareReplacement(replacement);

    if (Object.isString(pattern))
      pattern = RegExp.escape(pattern);

    if (!(pattern.length || pattern.source)) {
      replacement = replacement('');
      return replacement + source.split('').join(replacement) + replacement;
    }

    while (source.length > 0) {
      if (match = source.match(pattern)) {
        result += source.slice(0, match.index);
        result += String.interpret(replacement(match));
        source  = source.slice(match.index + match[0].length);
      } else {
        result += source, source = '';
      }
    }
    return result;
  }

  function sub(pattern, replacement, count) {
    replacement = prepareReplacement(replacement);
    count = Object.isUndefined(count) ? 1 : count;

    return this.gsub(pattern, function(match) {
      if (--count < 0) return match[0];
      return replacement(match);
    });
  }

  function scan(pattern, iterator) {
    this.gsub(pattern, iterator);
    return String(this);
  }

  function truncate(length, truncation) {
    length = length || 30;
    truncation = Object.isUndefined(truncation) ? '...' : truncation;
    return this.length > length ?
      this.slice(0, length - truncation.length) + truncation : String(this);
  }

  function strip() {
    return this.replace(/^\s+/, '').replace(/\s+$/, '');
  }

  function stripTags() {
    return this.replace(/<\w+(\s+("[^"]*"|'[^']*'|[^>])+)?>|<\/\w+>/gi, '');
  }

  function stripScripts() {
    return this.replace(new RegExp(Prototype.ScriptFragment, 'img'), '');
  }

  function extractScripts() {
    var matchAll = new RegExp(Prototype.ScriptFragment, 'img'),
        matchOne = new RegExp(Prototype.ScriptFragment, 'im');
    return (this.match(matchAll) || []).map(function(scriptTag) {
      return (scriptTag.match(matchOne) || ['', ''])[1];
    });
  }

  function evalScripts() {
    return this.extractScripts().map(function(script) { return eval(script) });
  }

  function escapeHTML() {
    return this.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
  }

  function unescapeHTML() {
    return this.stripTags().replace(/&lt;/g,'<').replace(/&gt;/g,'>').replace(/&amp;/g,'&');
  }


  function toQueryParams(separator) {
    var match = this.strip().match(/([^?#]*)(#.*)?$/);
    if (!match) return { };

    return match[1].split(separator || '&').inject({ }, function(hash, pair) {
      if ((pair = pair.split('='))[0]) {
        var key = decodeURIComponent(pair.shift()),
            value = pair.length > 1 ? pair.join('=') : pair[0];

        if (value != undefined) value = decodeURIComponent(value);

        if (key in hash) {
          if (!Object.isArray(hash[key])) hash[key] = [hash[key]];
          hash[key].push(value);
        }
        else hash[key] = value;
      }
      return hash;
    });
  }

  function toArray() {
    return this.split('');
  }

  function succ() {
    return this.slice(0, this.length - 1) +
      String.fromCharCode(this.charCodeAt(this.length - 1) + 1);
  }

  function times(count) {
    return count < 1 ? '' : new Array(count + 1).join(this);
  }

  function camelize() {
    return this.replace(/-+(.)?/g, function(match, chr) {
      return chr ? chr.toUpperCase() : '';
    });
  }

  function capitalize() {
    return this.charAt(0).toUpperCase() + this.substring(1).toLowerCase();
  }

  function underscore() {
    return this.replace(/::/g, '/')
               .replace(/([A-Z]+)([A-Z][a-z])/g, '$1_$2')
               .replace(/([a-z\d])([A-Z])/g, '$1_$2')
               .replace(/-/g, '_')
               .toLowerCase();
  }

  function dasherize() {
    return this.replace(/_/g, '-');
  }

  function inspect(useDoubleQuotes) {
    var escapedString = this.replace(/[\x00-\x1f\\]/g, function(character) {
      if (character in String.specialChar) {
        return String.specialChar[character];
      }
      return '\\u00' + character.charCodeAt().toPaddedString(2, 16);
    });
    if (useDoubleQuotes) return '"' + escapedString.replace(/"/g, '\\"') + '"';
    return "'" + escapedString.replace(/'/g, '\\\'') + "'";
  }

  function unfilterJSON(filter) {
    return this.replace(filter || Prototype.JSONFilter, '$1');
  }

  function isJSON() {
    var str = this;
    if (str.blank()) return false;
    str = str.replace(/\\(?:["\\\/bfnrt]|u[0-9a-fA-F]{4})/g, '@');
    str = str.replace(/"[^"\\\n\r]*"|true|false|null|-?\d+(?:\.\d*)?(?:[eE][+\-]?\d+)?/g, ']');
    str = str.replace(/(?:^|:|,)(?:\s*\[)+/g, '');
    return (/^[\],:{}\s]*$/).test(str);
  }

  function evalJSON(sanitize) {
    var json = this.unfilterJSON(),
        cx = /[\u0000\u00ad\u0600-\u0604\u070f\u17b4\u17b5\u200c-\u200f\u2028-\u202f\u2060-\u206f\ufeff\ufff0-\uffff]/g;
    if (cx.test(json)) {
      json = json.replace(cx, function (a) {
        return '\\u' + ('0000' + a.charCodeAt(0).toString(16)).slice(-4);
      });
    }
    try {
      if (!sanitize || json.isJSON()) return eval('(' + json + ')');
    } catch (e) { }
    throw new SyntaxError('Badly formed JSON string: ' + this.inspect());
  }

  function parseJSON() {
    var json = this.unfilterJSON();
    return JSON.parse(json);
  }

  function include(pattern) {
    return this.indexOf(pattern) > -1;
  }

  function startsWith(pattern) {
    return this.lastIndexOf(pattern, 0) === 0;
  }

  function endsWith(pattern) {
    var d = this.length - pattern.length;
    return d >= 0 && this.indexOf(pattern, d) === d;
  }

  function empty() {
    return this == '';
  }

  function blank() {
    return /^\s*$/.test(this);
  }

  function interpolate(object, pattern) {
    return new Template(this, pattern).evaluate(object);
  }

  return {
    gsub:           gsub,
    sub:            sub,
    scan:           scan,
    truncate:       truncate,
    strip:          String.prototype.trim || strip,
    stripTags:      stripTags,
    stripScripts:   stripScripts,
    extractScripts: extractScripts,
    evalScripts:    evalScripts,
    escapeHTML:     escapeHTML,
    unescapeHTML:   unescapeHTML,
    toQueryParams:  toQueryParams,
    parseQuery:     toQueryParams,
    toArray:        toArray,
    succ:           succ,
    times:          times,
    camelize:       camelize,
    capitalize:     capitalize,
    underscore:     underscore,
    dasherize:      dasherize,
    inspect:        inspect,
    unfilterJSON:   unfilterJSON,
    isJSON:         isJSON,
    evalJSON:       NATIVE_JSON_PARSE_SUPPORT ? parseJSON : evalJSON,
    include:        include,
    startsWith:     startsWith,
    endsWith:       endsWith,
    empty:          empty,
    blank:          blank,
    interpolate:    interpolate
  };
})());

var Template = Class.create({
  initialize: function(template, pattern) {
    this.template = template.toString();
    this.pattern = pattern || Template.Pattern;
  },

  evaluate: function(object) {
    if (object && Object.isFunction(object.toTemplateReplacements))
      object = object.toTemplateReplacements();

    return this.template.gsub(this.pattern, function(match) {
      if (object == null) return (match[1] + '');

      var before = match[1] || '';
      if (before == '\\') return match[2];

      var ctx = object, expr = match[3],
          pattern = /^([^.[]+|\[((?:.*?[^\\])?)\])(\.|\[|$)/;

      match = pattern.exec(expr);
      if (match == null) return before;

      while (match != null) {
        var comp = match[1].startsWith('[') ? match[2].replace(/\\\\]/g, ']') : match[1];
        ctx = ctx[comp];
        if (null == ctx || '' == match[3]) break;
        expr = expr.substring('[' == match[3] ? match[1].length : match[0].length);
        match = pattern.exec(expr);
      }

      return before + String.interpret(ctx);
    });
  }
});
Template.Pattern = /(^|.|\r|\n)(#\{(.*?)\})/;

var $break = { };

var Enumerable = (function() {
  function each(iterator, context) {
    var index = 0;
    try {
      this._each(function(value) {
        iterator.call(context, value, index++);
      });
    } catch (e) {
      if (e != $break) throw e;
    }
    return this;
  }

  function eachSlice(number, iterator, context) {
    var index = -number, slices = [], array = this.toArray();
    if (number < 1) return array;
    while ((index += number) < array.length)
      slices.push(array.slice(index, index+number));
    return slices.collect(iterator, context);
  }

  function all(iterator, context) {
    iterator = iterator || Prototype.K;
    var result = true;
    this.each(function(value, index) {
      result = result && !!iterator.call(context, value, index);
      if (!result) throw $break;
    });
    return result;
  }

  function any(iterator, context) {
    iterator = iterator || Prototype.K;
    var result = false;
    this.each(function(value, index) {
      if (result = !!iterator.call(context, value, index))
        throw $break;
    });
    return result;
  }

  function collect(iterator, context) {
    iterator = iterator || Prototype.K;
    var results = [];
    this.each(function(value, index) {
      results.push(iterator.call(context, value, index));
    });
    return results;
  }

  function detect(iterator, context) {
    var result;
    this.each(function(value, index) {
      if (iterator.call(context, value, index)) {
        result = value;
        throw $break;
      }
    });
    return result;
  }

  function findAll(iterator, context) {
    var results = [];
    this.each(function(value, index) {
      if (iterator.call(context, value, index))
        results.push(value);
    });
    return results;
  }

  function grep(filter, iterator, context) {
    iterator = iterator || Prototype.K;
    var results = [];

    if (Object.isString(filter))
      filter = new RegExp(RegExp.escape(filter));

    this.each(function(value, index) {
      if (filter.match(value))
        results.push(iterator.call(context, value, index));
    });
    return results;
  }

  function include(object) {
    if (Object.isFunction(this.indexOf))
      if (this.indexOf(object) != -1) return true;

    var found = false;
    this.each(function(value) {
      if (value == object) {
        found = true;
        throw $break;
      }
    });
    return found;
  }

  function inGroupsOf(number, fillWith) {
    fillWith = Object.isUndefined(fillWith) ? null : fillWith;
    return this.eachSlice(number, function(slice) {
      while(slice.length < number) slice.push(fillWith);
      return slice;
    });
  }

  function inject(memo, iterator, context) {
    this.each(function(value, index) {
      memo = iterator.call(context, memo, value, index);
    });
    return memo;
  }

  function invoke(method) {
    var args = $A(arguments).slice(1);
    return this.map(function(value) {
      return value[method].apply(value, args);
    });
  }

  function max(iterator, context) {
    iterator = iterator || Prototype.K;
    var result;
    this.each(function(value, index) {
      value = iterator.call(context, value, index);
      if (result == null || value >= result)
        result = value;
    });
    return result;
  }

  function min(iterator, context) {
    iterator = iterator || Prototype.K;
    var result;
    this.each(function(value, index) {
      value = iterator.call(context, value, index);
      if (result == null || value < result)
        result = value;
    });
    return result;
  }

  function partition(iterator, context) {
    iterator = iterator || Prototype.K;
    var trues = [], falses = [];
    this.each(function(value, index) {
      (iterator.call(context, value, index) ?
        trues : falses).push(value);
    });
    return [trues, falses];
  }

  function pluck(property) {
    var results = [];
    this.each(function(value) {
      results.push(value[property]);
    });
    return results;
  }

  function reject(iterator, context) {
    var results = [];
    this.each(function(value, index) {
      if (!iterator.call(context, value, index))
        results.push(value);
    });
    return results;
  }

  function sortBy(iterator, context) {
    return this.map(function(value, index) {
      return {
        value: value,
        criteria: iterator.call(context, value, index)
      };
    }).sort(function(left, right) {
      var a = left.criteria, b = right.criteria;
      return a < b ? -1 : a > b ? 1 : 0;
    }).pluck('value');
  }

  function toArray() {
    return this.map();
  }

  function zip() {
    var iterator = Prototype.K, args = $A(arguments);
    if (Object.isFunction(args.last()))
      iterator = args.pop();

    var collections = [this].concat(args).map($A);
    return this.map(function(value, index) {
      return iterator(collections.pluck(index));
    });
  }

  function size() {
    return this.toArray().length;
  }

  function inspect() {
    return '#<Enumerable:' + this.toArray().inspect() + '>';
  }









  return {
    each:       each,
    eachSlice:  eachSlice,
    all:        all,
    every:      all,
    any:        any,
    some:       any,
    collect:    collect,
    map:        collect,
    detect:     detect,
    findAll:    findAll,
    select:     findAll,
    filter:     findAll,
    grep:       grep,
    include:    include,
    member:     include,
    inGroupsOf: inGroupsOf,
    inject:     inject,
    invoke:     invoke,
    max:        max,
    min:        min,
    partition:  partition,
    pluck:      pluck,
    reject:     reject,
    sortBy:     sortBy,
    toArray:    toArray,
    entries:    toArray,
    zip:        zip,
    size:       size,
    inspect:    inspect,
    find:       detect
  };
})();

function $A(iterable) {
  if (!iterable) return [];
  if ('toArray' in Object(iterable)) return iterable.toArray();
  var length = iterable.length || 0, results = new Array(length);
  while (length--) results[length] = iterable[length];
  return results;
}


function $w(string) {
  if (!Object.isString(string)) return [];
  string = string.strip();
  return string ? string.split(/\s+/) : [];
}

Array.from = $A;


(function() {
  var arrayProto = Array.prototype,
      slice = arrayProto.slice,
      _each = arrayProto.forEach; // use native browser JS 1.6 implementation if available

  function each(iterator, context) {
    for (var i = 0, length = this.length >>> 0; i < length; i++) {
      if (i in this) iterator.call(context, this[i], i, this);
    }
  }
  if (!_each) _each = each;

  function clear() {
    this.length = 0;
    return this;
  }

  function first() {
    return this[0];
  }

  function last() {
    return this[this.length - 1];
  }

  function compact() {
    return this.select(function(value) {
      return value != null;
    });
  }

  function flatten() {
    return this.inject([], function(array, value) {
      if (Object.isArray(value))
        return array.concat(value.flatten());
      array.push(value);
      return array;
    });
  }

  function without() {
    var values = slice.call(arguments, 0);
    return this.select(function(value) {
      return !values.include(value);
    });
  }

  function reverse(inline) {
    return (inline === false ? this.toArray() : this)._reverse();
  }

  function uniq(sorted) {
    return this.inject([], function(array, value, index) {
      if (0 == index || (sorted ? array.last() != value : !array.include(value)))
        array.push(value);
      return array;
    });
  }

  function intersect(array) {
    return this.uniq().findAll(function(item) {
      return array.detect(function(value) { return item === value });
    });
  }


  function clone() {
    return slice.call(this, 0);
  }

  function size() {
    return this.length;
  }

  function inspect() {
    return '[' + this.map(Object.inspect).join(', ') + ']';
  }

  function indexOf(item, i) {
    i || (i = 0);
    var length = this.length;
    if (i < 0) i = length + i;
    for (; i < length; i++)
      if (this[i] === item) return i;
    return -1;
  }

  function lastIndexOf(item, i) {
    i = isNaN(i) ? this.length : (i < 0 ? this.length + i : i) + 1;
    var n = this.slice(0, i).reverse().indexOf(item);
    return (n < 0) ? n : i - n - 1;
  }

  function concat() {
    var array = slice.call(this, 0), item;
    for (var i = 0, length = arguments.length; i < length; i++) {
      item = arguments[i];
      if (Object.isArray(item) && !('callee' in item)) {
        for (var j = 0, arrayLength = item.length; j < arrayLength; j++)
          array.push(item[j]);
      } else {
        array.push(item);
      }
    }
    return array;
  }

  Object.extend(arrayProto, Enumerable);

  if (!arrayProto._reverse)
    arrayProto._reverse = arrayProto.reverse;

  Object.extend(arrayProto, {
    _each:     _each,
    clear:     clear,
    first:     first,
    last:      last,
    compact:   compact,
    flatten:   flatten,
    without:   without,
    reverse:   reverse,
    uniq:      uniq,
    intersect: intersect,
    clone:     clone,
    toArray:   clone,
    size:      size,
    inspect:   inspect
  });

  var CONCAT_ARGUMENTS_BUGGY = (function() {
    return [].concat(arguments)[0][0] !== 1;
  })(1,2)

  if (CONCAT_ARGUMENTS_BUGGY) arrayProto.concat = concat;

  if (!arrayProto.indexOf) arrayProto.indexOf = indexOf;
  if (!arrayProto.lastIndexOf) arrayProto.lastIndexOf = lastIndexOf;
})();
function $H(object) {
  return new Hash(object);
};

var Hash = Class.create(Enumerable, (function() {
  function initialize(object) {
    this._object = Object.isHash(object) ? object.toObject() : Object.clone(object);
  }


  function _each(iterator) {
    for (var key in this._object) {
      var value = this._object[key], pair = [key, value];
      pair.key = key;
      pair.value = value;
      iterator(pair);
    }
  }

  function set(key, value) {
    return this._object[key] = value;
  }

  function get(key) {
    if (this._object[key] !== Object.prototype[key])
      return this._object[key];
  }

  function unset(key) {
    var value = this._object[key];
    delete this._object[key];
    return value;
  }

  function toObject() {
    return Object.clone(this._object);
  }



  function keys() {
    return this.pluck('key');
  }

  function values() {
    return this.pluck('value');
  }

  function index(value) {
    var match = this.detect(function(pair) {
      return pair.value === value;
    });
    return match && match.key;
  }

  function merge(object) {
    return this.clone().update(object);
  }

  function update(object) {
    return new Hash(object).inject(this, function(result, pair) {
      result.set(pair.key, pair.value);
      return result;
    });
  }

  function toQueryPair(key, value) {
    if (Object.isUndefined(value)) return key;
    return key + '=' + encodeURIComponent(String.interpret(value));
  }

  function toQueryString() {
    return this.inject([], function(results, pair) {
      var key = encodeURIComponent(pair.key), values = pair.value;

      if (values && typeof values == 'object') {
        if (Object.isArray(values)) {
          var queryValues = [];
          for (var i = 0, len = values.length, value; i < len; i++) {
            value = values[i];
            queryValues.push(toQueryPair(key, value));
          }
          return results.concat(queryValues);
        }
      } else results.push(toQueryPair(key, values));
      return results;
    }).join('&');
  }

  function inspect() {
    return '#<Hash:{' + this.map(function(pair) {
      return pair.map(Object.inspect).join(': ');
    }).join(', ') + '}>';
  }

  function clone() {
    return new Hash(this);
  }

  return {
    initialize:             initialize,
    _each:                  _each,
    set:                    set,
    get:                    get,
    unset:                  unset,
    toObject:               toObject,
    toTemplateReplacements: toObject,
    keys:                   keys,
    values:                 values,
    index:                  index,
    merge:                  merge,
    update:                 update,
    toQueryString:          toQueryString,
    inspect:                inspect,
    toJSON:                 toObject,
    clone:                  clone
  };
})());

Hash.from = $H;
Object.extend(Number.prototype, (function() {
  function toColorPart() {
    return this.toPaddedString(2, 16);
  }

  function succ() {
    return this + 1;
  }

  function times(iterator, context) {
    $R(0, this, true).each(iterator, context);
    return this;
  }

  function toPaddedString(length, radix) {
    var string = this.toString(radix || 10);
    return '0'.times(length - string.length) + string;
  }

  function abs() {
    return Math.abs(this);
  }

  function round() {
    return Math.round(this);
  }

  function ceil() {
    return Math.ceil(this);
  }

  function floor() {
    return Math.floor(this);
  }

  return {
    toColorPart:    toColorPart,
    succ:           succ,
    times:          times,
    toPaddedString: toPaddedString,
    abs:            abs,
    round:          round,
    ceil:           ceil,
    floor:          floor
  };
})());

function $R(start, end, exclusive) {
  return new ObjectRange(start, end, exclusive);
}

var ObjectRange = Class.create(Enumerable, (function() {
  function initialize(start, end, exclusive) {
    this.start = start;
    this.end = end;
    this.exclusive = exclusive;
  }

  function _each(iterator) {
    var value = this.start;
    while (this.include(value)) {
      iterator(value);
      value = value.succ();
    }
  }

  function include(value) {
    if (value < this.start)
      return false;
    if (this.exclusive)
      return value < this.end;
    return value <= this.end;
  }

  return {
    initialize: initialize,
    _each:      _each,
    include:    include
  };
})());



var Ajax = {
  getTransport: function() {
    return Try.these(
      function() {return new XMLHttpRequest()},
      function() {return new ActiveXObject('Msxml2.XMLHTTP')},
      function() {return new ActiveXObject('Microsoft.XMLHTTP')}
    ) || false;
  },

  activeRequestCount: 0
};

Ajax.Responders = {
  responders: [],

  _each: function(iterator) {
    this.responders._each(iterator);
  },

  register: function(responder) {
    if (!this.include(responder))
      this.responders.push(responder);
  },

  unregister: function(responder) {
    this.responders = this.responders.without(responder);
  },

  dispatch: function(callback, request, transport, json) {
    this.each(function(responder) {
      if (Object.isFunction(responder[callback])) {
        try {
          responder[callback].apply(responder, [request, transport, json]);
        } catch (e) { }
      }
    });
  }
};

Object.extend(Ajax.Responders, Enumerable);

Ajax.Responders.register({
  onCreate:   function() { Ajax.activeRequestCount++ },
  onComplete: function() { Ajax.activeRequestCount-- }
});
Ajax.Base = Class.create({
  initialize: function(options) {
    this.options = {
      method:       'post',
      asynchronous: true,
      contentType:  'application/x-www-form-urlencoded',
      encoding:     'UTF-8',
      parameters:   '',
      evalJSON:     true,
      evalJS:       true
    };
    Object.extend(this.options, options || { });

    this.options.method = this.options.method.toLowerCase();

    if (Object.isHash(this.options.parameters))
      this.options.parameters = this.options.parameters.toObject();
  }
});
Ajax.Request = Class.create(Ajax.Base, {
  _complete: false,

  initialize: function($super, url, options) {
    $super(options);
    this.transport = Ajax.getTransport();
    this.request(url);
  },

  request: function(url) {
    this.url = url;
    this.method = this.options.method;
    var params = Object.isString(this.options.parameters) ?
          this.options.parameters :
          Object.toQueryString(this.options.parameters);

    if (!['get', 'post'].include(this.method)) {
      params += (params ? '&' : '') + "_method=" + this.method;
      this.method = 'post';
    }

    if (params && this.method === 'get') {
      this.url += (this.url.include('?') ? '&' : '?') + params;
    }

    this.parameters = params.toQueryParams();

    try {
      var response = new Ajax.Response(this);
      if (this.options.onCreate) this.options.onCreate(response);
      Ajax.Responders.dispatch('onCreate', this, response);

      this.transport.open(this.method.toUpperCase(), this.url,
        this.options.asynchronous);

      if (this.options.asynchronous) this.respondToReadyState.bind(this).defer(1);

      this.transport.onreadystatechange = this.onStateChange.bind(this);
      this.setRequestHeaders();

      this.body = this.method == 'post' ? (this.options.postBody || params) : null;
      this.transport.send(this.body);

      /* Force Firefox to handle ready state 4 for synchronous requests */
      if (!this.options.asynchronous && this.transport.overrideMimeType)
        this.onStateChange();

    }
    catch (e) {
      this.dispatchException(e);
    }
  },

  onStateChange: function() {
    var readyState = this.transport.readyState;
    if (readyState > 1 && !((readyState == 4) && this._complete))
      this.respondToReadyState(this.transport.readyState);
  },

  setRequestHeaders: function() {
    var headers = {
      'X-Requested-With': 'XMLHttpRequest',
    // 'X-Prototype-Version': Prototype.Version,
      'Accept': 'text/javascript, text/html, application/xml, text/xml, */*'
    };

    if (this.method == 'post') {
      // Don't touch contentType if we've been told not to.
      if(this.options.contentType != null)
      headers['Content-type'] = this.options.contentType +
        (this.options.encoding ? '; charset=' + this.options.encoding : '');

      /* Force "Connection: close" for older Mozilla browsers to work
       * around a bug where XMLHttpRequest sends an incorrect
       * Content-length header. See Mozilla Bugzilla #246651.
       */
      if (this.transport.overrideMimeType &&
          (navigator.userAgent.match(/Gecko\/(\d{4})/) || [0,2005])[1] < 2005)
            headers['Connection'] = 'close';
    }

    if (typeof this.options.requestHeaders == 'object') {
      var extras = this.options.requestHeaders;

      if (Object.isFunction(extras.push))
        for (var i = 0, length = extras.length; i < length; i += 2)
          headers[extras[i]] = extras[i+1];
      else
        $H(extras).each(function(pair) { headers[pair.key] = pair.value });
    }

    for (var name in headers)
      this.transport.setRequestHeader(name, headers[name]);
  },

  success: function() {
    var status = this.getStatus();
    return !status || (status >= 200 && status < 300) || status == 304;
  },

  getStatus: function() {
    try {
      if (this.transport.status === 1223) return 204;
      return this.transport.status || 0;
    } catch (e) { return 0 }
  },

  respondToReadyState: function(readyState) {
    var state = Ajax.Request.Events[readyState], response = new Ajax.Response(this);

    if (state == 'Complete') {
      try {
        this._complete = true;
        (this.options['on' + response.status]
         || this.options['on' + (this.success() ? 'Success' : 'Failure')]
         || Prototype.emptyFunction)(response, response.headerJSON);
      } catch (e) {
        this.dispatchException(e);
      }

      var contentType = response.getHeader('Content-type');
      if (this.options.evalJS == 'force'
          || (this.options.evalJS && this.isSameOrigin() && contentType
          && contentType.match(/^\s*(text|application)\/(x-)?(java|ecma)script(;.*)?\s*$/i)))
        this.evalResponse();
    }

    try {
      (this.options['on' + state] || Prototype.emptyFunction)(response, response.headerJSON);
      Ajax.Responders.dispatch('on' + state, this, response, response.headerJSON);
    } catch (e) {
      this.dispatchException(e);
    }

    if (state == 'Complete') {
      this.transport.onreadystatechange = Prototype.emptyFunction;
    }
  },

  isSameOrigin: function() {
    var m = this.url.match(/^\s*https?:\/\/[^\/]*/);
    return !m || (m[0] == '#{protocol}//#{domain}#{port}'.interpolate({
      protocol: location.protocol,
      domain: document.domain,
      port: location.port ? ':' + location.port : ''
    }));
  },

  getHeader: function(name) {
    try {
      return this.transport.getResponseHeader(name) || null;
    } catch (e) { return null; }
  },

  evalResponse: function() {
    try {
      return eval((this.transport.responseText || '').unfilterJSON());
    } catch (e) {
      this.dispatchException(e);
    }
  },

  dispatchException: function(exception) {
    (this.options.onException || Prototype.emptyFunction)(this, exception);
    Ajax.Responders.dispatch('onException', this, exception);
  }
});

Ajax.Request.Events =
  ['Uninitialized', 'Loading', 'Loaded', 'Interactive', 'Complete'];








Ajax.Response = Class.create({
  initialize: function(request){
    this.request = request;
    var transport  = this.transport  = request.transport,
        readyState = this.readyState = transport.readyState;

    if ((readyState > 2 && !Prototype.Browser.IE) || readyState == 4) {
      this.status       = this.getStatus();
      this.statusText   = this.getStatusText();
      this.responseText = String.interpret(transport.responseText);
      this.headerJSON   = this._getHeaderJSON();
    }

    if (readyState == 4) {
      var xml = transport.responseXML;
      this.responseXML  = Object.isUndefined(xml) ? null : xml;
      this.responseJSON = this._getResponseJSON();
    }
  },

  status:      0,

  statusText: '',

  getStatus: Ajax.Request.prototype.getStatus,

  getStatusText: function() {
    try {
      return this.transport.statusText || '';
    } catch (e) { return '' }
  },

  getHeader: Ajax.Request.prototype.getHeader,

  getAllHeaders: function() {
    try {
      return this.getAllResponseHeaders();
    } catch (e) { return null }
  },

  getResponseHeader: function(name) {
    return this.transport.getResponseHeader(name);
  },

  getAllResponseHeaders: function() {
    return this.transport.getAllResponseHeaders();
  },

  _getHeaderJSON: function() {
    var json = this.getHeader('X-JSON');
    if (!json) return null;
    json = decodeURIComponent(escape(json));
    try {
      return json.evalJSON(this.request.options.sanitizeJSON ||
        !this.request.isSameOrigin());
    } catch (e) {
      this.request.dispatchException(e);
    }
  },

  _getResponseJSON: function() {
    var options = this.request.options;
    if (!options.evalJSON || (options.evalJSON != 'force' &&
      !(this.getHeader('Content-type') || '').include('application/json')) ||
        this.responseText.blank())
          return null;
    try {
      return this.responseText.evalJSON(options.sanitizeJSON ||
        !this.request.isSameOrigin());
    } catch (e) {
      this.request.dispatchException(e);
    }
  }
});

Ajax.Updater = Class.create(Ajax.Request, {
  initialize: function($super, container, url, options) {
    this.container = {
      success: (container.success || container),
      failure: (container.failure || (container.success ? null : container))
    };

    options = Object.clone(options);
    var onComplete = options.onComplete;
    options.onComplete = (function(response, json) {
      this.updateContent(response.responseText);
      if (Object.isFunction(onComplete)) onComplete(response, json);
    }).bind(this);

    $super(url, options);
  },

  updateContent: function(responseText) {
    var receiver = this.container[this.success() ? 'success' : 'failure'],
        options = this.options;

    if (!options.evalScripts) responseText = responseText.stripScripts();

    if (receiver = $(receiver)) {
      if (options.insertion) {
        if (Object.isString(options.insertion)) {
          var insertion = { }; insertion[options.insertion] = responseText;
          receiver.insert(insertion);
        }
        else options.insertion(receiver, responseText);
      }
      else receiver.update(responseText);
    }
  }
});

Ajax.PeriodicalUpdater = Class.create(Ajax.Base, {
  initialize: function($super, container, url, options) {
    $super(options);
    this.onComplete = this.options.onComplete;

    this.frequency = (this.options.frequency || 2);
    this.decay = (this.options.decay || 1);

    this.updater = { };
    this.container = container;
    this.url = url;

    this.start();
  },

  start: function() {
    this.options.onComplete = this.updateComplete.bind(this);
    this.onTimerEvent();
  },

  stop: function() {
    this.updater.options.onComplete = undefined;
    clearTimeout(this.timer);
    (this.onComplete || Prototype.emptyFunction).apply(this, arguments);
  },

  updateComplete: function(response) {
    if (this.options.decay) {
      this.decay = (response.responseText == this.lastText ?
        this.decay * this.options.decay : 1);

      this.lastText = response.responseText;
    }
    this.timer = this.onTimerEvent.bind(this).delay(this.decay * this.frequency);
  },

  onTimerEvent: function() {
    this.updater = new Ajax.Updater(this.container, this.url, this.options);
  }
});


function $(element) {
  if (arguments.length > 1) {
    for (var i = 0, elements = [], length = arguments.length; i < length; i++)
      elements.push($(arguments[i]));
    return elements;
  }
  if (Object.isString(element))
    element = document.getElementById(element);
  return Element.extend(element);
}

if (Prototype.BrowserFeatures.XPath) {
  document._getElementsByXPath = function(expression, parentElement) {
    var results = [];
    var query = document.evaluate(expression, $(parentElement) || document,
      null, XPathResult.ORDERED_NODE_SNAPSHOT_TYPE, null);
    for (var i = 0, length = query.snapshotLength; i < length; i++)
      results.push(Element.extend(query.snapshotItem(i)));
    return results;
  };
}

/*--------------------------------------------------------------------------*/

if (!Node) var Node = { };

if (!Node.ELEMENT_NODE) {
  Object.extend(Node, {
    ELEMENT_NODE: 1,
    ATTRIBUTE_NODE: 2,
    TEXT_NODE: 3,
    CDATA_SECTION_NODE: 4,
    ENTITY_REFERENCE_NODE: 5,
    ENTITY_NODE: 6,
    PROCESSING_INSTRUCTION_NODE: 7,
    COMMENT_NODE: 8,
    DOCUMENT_NODE: 9,
    DOCUMENT_TYPE_NODE: 10,
    DOCUMENT_FRAGMENT_NODE: 11,
    NOTATION_NODE: 12
  });
}



(function(global) {
  function shouldUseCache(tagName, attributes) {
    if (tagName === 'select') return false;
    if ('type' in attributes) return false;
    return true;
  }

  var HAS_EXTENDED_CREATE_ELEMENT_SYNTAX = (function(){
    try {
      var el = document.createElement('<input name="x">');
      return el.tagName.toLowerCase() === 'input' && el.name === 'x';
    }
    catch(err) {
      return false;
    }
  })();

  var element = global.Element;

  global.Element = function(tagName, attributes) {
    attributes = attributes || { };
    tagName = tagName.toLowerCase();
    var cache = Element.cache;

    if (HAS_EXTENDED_CREATE_ELEMENT_SYNTAX && attributes.name) {
      tagName = '<' + tagName + ' name="' + attributes.name + '">';
      delete attributes.name;
      return Element.writeAttribute(document.createElement(tagName), attributes);
    }

    if (!cache[tagName]) cache[tagName] = Element.extend(document.createElement(tagName));

    var node = shouldUseCache(tagName, attributes) ?
     cache[tagName].cloneNode(false) : document.createElement(tagName);

    return Element.writeAttribute(node, attributes);
  };

  Object.extend(global.Element, element || { });
  if (element) global.Element.prototype = element.prototype;

})(this);

Element.idCounter = 1;
Element.cache = { };

Element._purgeElement = function(element) {
  var uid = element._prototypeUID;
  if (uid) {
    Element.stopObserving(element);
    element._prototypeUID = void 0;
    delete Element.Storage[uid];
  }
}

Element.Methods = {
  visible: function(element) {
    return $(element).style.display != 'none';
  },

  toggle: function(element) {
    element = $(element);
    Element[Element.visible(element) ? 'hide' : 'show'](element);
    return element;
  },

  hide: function(element) {
    element = $(element);
    element.style.display = 'none';
    return element;
  },

  show: function(element) {
    element = $(element);
    element.style.display = '';
    return element;
  },

  remove: function(element) {
    element = $(element);
    element.parentNode.removeChild(element);
    return element;
  },

  update: (function(){

    var SELECT_ELEMENT_INNERHTML_BUGGY = (function(){
      var el = document.createElement("select"),
          isBuggy = true;
      el.innerHTML = "<option value=\"test\">test</option>";
      if (el.options && el.options[0]) {
        isBuggy = el.options[0].nodeName.toUpperCase() !== "OPTION";
      }
      el = null;
      return isBuggy;
    })();

    var TABLE_ELEMENT_INNERHTML_BUGGY = (function(){
      try {
        var el = document.createElement("table");
        if (el && el.tBodies) {
          el.innerHTML = "<tbody><tr><td>test</td></tr></tbody>";
          var isBuggy = typeof el.tBodies[0] == "undefined";
          el = null;
          return isBuggy;
        }
      } catch (e) {
        return true;
      }
    })();

    var LINK_ELEMENT_INNERHTML_BUGGY = (function() {
      try {
        var el = document.createElement('div');
        el.innerHTML = "<link>";
        var isBuggy = (el.childNodes.length === 0);
        el = null;
        return isBuggy;
      } catch(e) {
        return true;
      }
    })();

    var ANY_INNERHTML_BUGGY = SELECT_ELEMENT_INNERHTML_BUGGY ||
     TABLE_ELEMENT_INNERHTML_BUGGY || LINK_ELEMENT_INNERHTML_BUGGY;

    var SCRIPT_ELEMENT_REJECTS_TEXTNODE_APPENDING = (function () {
      var s = document.createElement("script"),
          isBuggy = false;
      try {
        s.appendChild(document.createTextNode(""));
        isBuggy = !s.firstChild ||
          s.firstChild && s.firstChild.nodeType !== 3;
      } catch (e) {
        isBuggy = true;
      }
      s = null;
      return isBuggy;
    })();


    function update(element, content) {
      element = $(element);
      var purgeElement = Element._purgeElement;

      var descendants = element.getElementsByTagName('*'),
       i = descendants.length;
      while (i--) purgeElement(descendants[i]);

      if (content && content.toElement)
        content = content.toElement();

      if (Object.isElement(content))
        return element.update().insert(content);

      content = Object.toHTML(content);

      var tagName = element.tagName.toUpperCase();

      if (tagName === 'SCRIPT' && SCRIPT_ELEMENT_REJECTS_TEXTNODE_APPENDING) {
        element.text = content;
        return element;
      }

      if (ANY_INNERHTML_BUGGY) {
        if (tagName in Element._insertionTranslations.tags) {
          while (element.firstChild) {
            element.removeChild(element.firstChild);
          }
          Element._getContentFromAnonymousElement(tagName, content.stripScripts())
            .each(function(node) {
              element.appendChild(node)
            });
        } else if (LINK_ELEMENT_INNERHTML_BUGGY && Object.isString(content) && content.indexOf('<link') > -1) {
          while (element.firstChild) {
            element.removeChild(element.firstChild);
          }
          var nodes = Element._getContentFromAnonymousElement(tagName, content.stripScripts(), true);
          nodes.each(function(node) { element.appendChild(node) });
        }
        else {
          element.innerHTML = content.stripScripts();
        }
      }
      else {
        element.innerHTML = content.stripScripts();
      }

      content.evalScripts.bind(content).defer();
      return element;
    }

    return update;
  })(),

  replace: function(element, content) {
    element = $(element);
    if (content && content.toElement) content = content.toElement();
    else if (!Object.isElement(content)) {
      content = Object.toHTML(content);
      var range = element.ownerDocument.createRange();
      range.selectNode(element);
      content.evalScripts.bind(content).defer();
      content = range.createContextualFragment(content.stripScripts());
    }
    element.parentNode.replaceChild(content, element);
    return element;
  },

  insert: function(element, insertions) {
    element = $(element);

    if (Object.isString(insertions) || Object.isNumber(insertions) ||
        Object.isElement(insertions) || (insertions && (insertions.toElement || insertions.toHTML)))
          insertions = {bottom:insertions};

    var content, insert, tagName, childNodes;

    for (var position in insertions) {
      content  = insertions[position];
      position = position.toLowerCase();
      insert = Element._insertionTranslations[position];

      if (content && content.toElement) content = content.toElement();
      if (Object.isElement(content)) {
        insert(element, content);
        continue;
      }

      content = Object.toHTML(content);

      tagName = ((position == 'before' || position == 'after')
        ? element.parentNode : element).tagName.toUpperCase();

      childNodes = Element._getContentFromAnonymousElement(tagName, content.stripScripts());

      if (position == 'top' || position == 'after') childNodes.reverse();
      childNodes.each(insert.curry(element));

      content.evalScripts.bind(content).defer();
    }

    return element;
  },

  wrap: function(element, wrapper, attributes) {
    element = $(element);
    if (Object.isElement(wrapper))
      $(wrapper).writeAttribute(attributes || { });
    else if (Object.isString(wrapper)) wrapper = new Element(wrapper, attributes);
    else wrapper = new Element('div', wrapper);
    if (element.parentNode)
      element.parentNode.replaceChild(wrapper, element);
    wrapper.appendChild(element);
    return wrapper;
  },

  inspect: function(element) {
    element = $(element);
    var result = '<' + element.tagName.toLowerCase();
    $H({'id': 'id', 'className': 'class'}).each(function(pair) {
      var property = pair.first(),
          attribute = pair.last(),
          value = (element[property] || '').toString();
      if (value) result += ' ' + attribute + '=' + value.inspect(true);
    });
    return result + '>';
  },

  recursivelyCollect: function(element, property, maximumLength) {
    element = $(element);
    maximumLength = maximumLength || -1;
    var elements = [];

    while (element = element[property]) {
      if (element.nodeType == 1)
        elements.push(Element.extend(element));
      if (elements.length == maximumLength)
        break;
    }

    return elements;
  },

  ancestors: function(element) {
    return Element.recursivelyCollect(element, 'parentNode');
  },

  descendants: function(element) {
    return Element.select(element, "*");
  },

  firstDescendant: function(element) {
    element = $(element).firstChild;
    while (element && element.nodeType != 1) element = element.nextSibling;
    return $(element);
  },

  immediateDescendants: function(element) {
    var results = [], child = $(element).firstChild;
    while (child) {
      if (child.nodeType === 1) {
        results.push(Element.extend(child));
      }
      child = child.nextSibling;
    }
    return results;
  },

  previousSiblings: function(element, maximumLength) {
    return Element.recursivelyCollect(element, 'previousSibling');
  },

  nextSiblings: function(element) {
    return Element.recursivelyCollect(element, 'nextSibling');
  },

  siblings: function(element) {
    element = $(element);
    return Element.previousSiblings(element).reverse()
      .concat(Element.nextSiblings(element));
  },

  match: function(element, selector) {
    element = $(element);
    if (Object.isString(selector))
      return Prototype.Selector.match(element, selector);
    return selector.match(element);
  },

  up: function(element, expression, index) {
    element = $(element);
    if (arguments.length == 1) return $(element.parentNode);
    var ancestors = Element.ancestors(element);
    return Object.isNumber(expression) ? ancestors[expression] :
      Prototype.Selector.find(ancestors, expression, index);
  },

  down: function(element, expression, index) {
    element = $(element);
    if (arguments.length == 1) return Element.firstDescendant(element);
    return Object.isNumber(expression) ? Element.descendants(element)[expression] :
      Element.select(element, expression)[index || 0];
  },

  previous: function(element, expression, index) {
    element = $(element);
    if (Object.isNumber(expression)) index = expression, expression = false;
    if (!Object.isNumber(index)) index = 0;

    if (expression) {
      return Prototype.Selector.find(element.previousSiblings(), expression, index);
    } else {
      return element.recursivelyCollect("previousSibling", index + 1)[index];
    }
  },

  next: function(element, expression, index) {
    element = $(element);
    if (Object.isNumber(expression)) index = expression, expression = false;
    if (!Object.isNumber(index)) index = 0;

    if (expression) {
      return Prototype.Selector.find(element.nextSiblings(), expression, index);
    } else {
      var maximumLength = Object.isNumber(index) ? index + 1 : 1;
      return element.recursivelyCollect("nextSibling", index + 1)[index];
    }
  },


  select: function(element) {
    element = $(element);
    var expressions = Array.prototype.slice.call(arguments, 1).join(', ');
    return Prototype.Selector.select(expressions, element);
  },

  adjacent: function(element) {
    element = $(element);
    var expressions = Array.prototype.slice.call(arguments, 1).join(', ');
    return Prototype.Selector.select(expressions, element.parentNode).without(element);
  },

  identify: function(element) {
    element = $(element);
    var id = Element.readAttribute(element, 'id');
    if (id) return id;
    do { id = 'anonymous_element_' + Element.idCounter++ } while ($(id));
    Element.writeAttribute(element, 'id', id);
    return id;
  },

  readAttribute: function(element, name) {
    element = $(element);
    if (Prototype.Browser.IE) {
      var t = Element._attributeTranslations.read;
      if (t.values[name]) return t.values[name](element, name);
      if (t.names[name]) name = t.names[name];
      if (name.include(':')) {
        return (!element.attributes || !element.attributes[name]) ? null :
         element.attributes[name].value;
      }
    }
    return element.getAttribute(name);
  },

  writeAttribute: function(element, name, value) {
    element = $(element);
    var attributes = { }, t = Element._attributeTranslations.write;

    if (typeof name == 'object') attributes = name;
    else attributes[name] = Object.isUndefined(value) ? true : value;

    for (var attr in attributes) {
      name = t.names[attr] || attr;
      value = attributes[attr];
      if (t.values[attr]) name = t.values[attr](element, value);
      if (value === false || value === null)
        element.removeAttribute(name);
      else if (value === true)
        element.setAttribute(name, name);
      else element.setAttribute(name, value);
    }
    return element;
  },

  getHeight: function(element) {
    return Element.getDimensions(element).height;
  },

  getWidth: function(element) {
    return Element.getDimensions(element).width;
  },

  classNames: function(element) {
    return new Element.ClassNames(element);
  },

  hasClassName: function(element, className) {
    if (!(element = $(element))) return;
    var elementClassName = element.className;
    return (elementClassName.length > 0 && (elementClassName == className ||
      new RegExp("(^|\\s)" + className + "(\\s|$)").test(elementClassName)));
  },

  addClassName: function(element, className) {
    if (!(element = $(element))) return;
    if (!Element.hasClassName(element, className))
      element.className += (element.className ? ' ' : '') + className;
    return element;
  },

  removeClassName: function(element, className) {
    if (!(element = $(element))) return;
    element.className = element.className.replace(
      new RegExp("(^|\\s+)" + className + "(\\s+|$)"), ' ').strip();
    return element;
  },

  toggleClassName: function(element, className) {
    if (!(element = $(element))) return;
    return Element[Element.hasClassName(element, className) ?
      'removeClassName' : 'addClassName'](element, className);
  },

  cleanWhitespace: function(element) {
    element = $(element);
    var node = element.firstChild;
    while (node) {
      var nextNode = node.nextSibling;
      if (node.nodeType == 3 && !/\S/.test(node.nodeValue))
        element.removeChild(node);
      node = nextNode;
    }
    return element;
  },

  empty: function(element) {
    return $(element).innerHTML.blank();
  },

  descendantOf: function(element, ancestor) {
    element = $(element), ancestor = $(ancestor);

    if (element.compareDocumentPosition)
      return (element.compareDocumentPosition(ancestor) & 8) === 8;

    if (ancestor.contains)
      return ancestor.contains(element) && ancestor !== element;

    while (element = element.parentNode)
      if (element == ancestor) return true;

    return false;
  },

  scrollTo: function(element) {
    element = $(element);
    var pos = Element.cumulativeOffset(element);
    window.scrollTo(pos[0], pos[1]);
    return element;
  },

  getStyle: function(element, style) {
    element = $(element);
    style = style == 'float' ? 'cssFloat' : style.camelize();
    var value = element.style[style];
    if (!value || value == 'auto') {
      var css = document.defaultView.getComputedStyle(element, null);
      value = css ? css[style] : null;
    }
    if (style == 'opacity') return value ? parseFloat(value) : 1.0;
    return value == 'auto' ? null : value;
  },

  getOpacity: function(element) {
    return $(element).getStyle('opacity');
  },

  setStyle: function(element, styles) {
    element = $(element);
    var elementStyle = element.style, match;
    if (Object.isString(styles)) {
      element.style.cssText += ';' + styles;
      return styles.include('opacity') ?
        element.setOpacity(styles.match(/opacity:\s*(\d?\.?\d*)/)[1]) : element;
    }
    for (var property in styles)
      if (property == 'opacity') element.setOpacity(styles[property]);
      else
        elementStyle[(property == 'float' || property == 'cssFloat') ?
          (Object.isUndefined(elementStyle.styleFloat) ? 'cssFloat' : 'styleFloat') :
            property] = styles[property];

    return element;
  },

  setOpacity: function(element, value) {
    element = $(element);
    element.style.opacity = (value == 1 || value === '') ? '' :
      (value < 0.00001) ? 0 : value;
    return element;
  },

  makePositioned: function(element) {
    element = $(element);
    var pos = Element.getStyle(element, 'position');
    if (pos == 'static' || !pos) {
      element._madePositioned = true;
      element.style.position = 'relative';
      if (Prototype.Browser.Opera) {
        element.style.top = 0;
        element.style.left = 0;
      }
    }
    return element;
  },

  undoPositioned: function(element) {
    element = $(element);
    if (element._madePositioned) {
      element._madePositioned = undefined;
      element.style.position =
        element.style.top =
        element.style.left =
        element.style.bottom =
        element.style.right = '';
    }
    return element;
  },

  makeClipping: function(element) {
    element = $(element);
    if (element._overflow) return element;
    element._overflow = Element.getStyle(element, 'overflow') || 'auto';
    if (element._overflow !== 'hidden')
      element.style.overflow = 'hidden';
    return element;
  },

  undoClipping: function(element) {
    element = $(element);
    if (!element._overflow) return element;
    element.style.overflow = element._overflow == 'auto' ? '' : element._overflow;
    element._overflow = null;
    return element;
  },

  clonePosition: function(element, source) {
    var options = Object.extend({
      setLeft:    true,
      setTop:     true,
      setWidth:   true,
      setHeight:  true,
      offsetTop:  0,
      offsetLeft: 0
    }, arguments[2] || { });

    source = $(source);
    var p = Element.viewportOffset(source), delta = [0, 0], parent = null;

    element = $(element);

    if (Element.getStyle(element, 'position') == 'absolute') {
      parent = Element.getOffsetParent(element);
      delta = Element.viewportOffset(parent);
    }

    if (parent == document.body) {
      delta[0] -= document.body.offsetLeft;
      delta[1] -= document.body.offsetTop;
    }

    if (options.setLeft)   element.style.left  = (p[0] - delta[0] + options.offsetLeft) + 'px';
    if (options.setTop)    element.style.top   = (p[1] - delta[1] + options.offsetTop) + 'px';
    if (options.setWidth)  element.style.width = source.offsetWidth + 'px';
    if (options.setHeight) element.style.height = source.offsetHeight + 'px';
    return element;
  }
};

Object.extend(Element.Methods, {
  getElementsBySelector: Element.Methods.select,

  childElements: Element.Methods.immediateDescendants
});

Element._attributeTranslations = {
  write: {
    names: {
      className: 'class',
      htmlFor:   'for'
    },
    values: { }
  }
};

if (Prototype.Browser.Opera) {
  Element.Methods.getStyle = Element.Methods.getStyle.wrap(
    function(proceed, element, style) {
      switch (style) {
        case 'height': case 'width':
          if (!Element.visible(element)) return null;

          var dim = parseInt(proceed(element, style), 10);

          if (dim !== element['offset' + style.capitalize()])
            return dim + 'px';

          var properties;
          if (style === 'height') {
            properties = ['border-top-width', 'padding-top',
             'padding-bottom', 'border-bottom-width'];
          }
          else {
            properties = ['border-left-width', 'padding-left',
             'padding-right', 'border-right-width'];
          }
          return properties.inject(dim, function(memo, property) {
            var val = proceed(element, property);
            return val === null ? memo : memo - parseInt(val, 10);
          }) + 'px';
        default: return proceed(element, style);
      }
    }
  );

  Element.Methods.readAttribute = Element.Methods.readAttribute.wrap(
    function(proceed, element, attribute) {
      if (attribute === 'title') return element.title;
      return proceed(element, attribute);
    }
  );
}

else if (Prototype.Browser.IE) {
  Element.Methods.getStyle = function(element, style) {
    element = $(element);
    style = (style == 'float' || style == 'cssFloat') ? 'styleFloat' : style.camelize();
    var value = element.style[style];
    if (!value && element.currentStyle) value = element.currentStyle[style];

    if (style == 'opacity') {
      if (value = (element.getStyle('filter') || '').match(/alpha\(opacity=(.*)\)/))
        if (value[1]) return parseFloat(value[1]) / 100;
      return 1.0;
    }

    if (value == 'auto') {
      if ((style == 'width' || style == 'height') && (element.getStyle('display') != 'none'))
        return element['offset' + style.capitalize()] + 'px';
      return null;
    }
    return value;
  };

  Element.Methods.setOpacity = function(element, value) {
    function stripAlpha(filter){
      return filter.replace(/alpha\([^\)]*\)/gi,'');
    }
    element = $(element);
    var currentStyle = element.currentStyle;
    if ((currentStyle && !currentStyle.hasLayout) ||
      (!currentStyle && element.style.zoom == 'normal'))
        element.style.zoom = 1;

    var filter = element.getStyle('filter'), style = element.style;
    if (value == 1 || value === '') {
      (filter = stripAlpha(filter)) ?
        style.filter = filter : style.removeAttribute('filter');
      return element;
    } else if (value < 0.00001) value = 0;
    style.filter = stripAlpha(filter) +
      'alpha(opacity=' + (value * 100) + ')';
    return element;
  };

  Element._attributeTranslations = (function(){

    var classProp = 'className',
        forProp = 'for',
        el = document.createElement('div');

    el.setAttribute(classProp, 'x');

    if (el.className !== 'x') {
      el.setAttribute('class', 'x');
      if (el.className === 'x') {
        classProp = 'class';
      }
    }
    el = null;

    el = document.createElement('label');
    el.setAttribute(forProp, 'x');
    if (el.htmlFor !== 'x') {
      el.setAttribute('htmlFor', 'x');
      if (el.htmlFor === 'x') {
        forProp = 'htmlFor';
      }
    }
    el = null;

    return {
      read: {
        names: {
          'class':      classProp,
          'className':  classProp,
          'for':        forProp,
          'htmlFor':    forProp
        },
        values: {
          _getAttr: function(element, attribute) {
            return element.getAttribute(attribute);
          },
          _getAttr2: function(element, attribute) {
            return element.getAttribute(attribute, 2);
          },
          _getAttrNode: function(element, attribute) {
            var node = element.getAttributeNode(attribute);
            return node ? node.value : "";
          },
          _getEv: (function(){

            var el = document.createElement('div'), f;
            el.onclick = Prototype.emptyFunction;
            var value = el.getAttribute('onclick');

            if (String(value).indexOf('{') > -1) {
              f = function(element, attribute) {
                attribute = element.getAttribute(attribute);
                if (!attribute) return null;
                attribute = attribute.toString();
                attribute = attribute.split('{')[1];
                attribute = attribute.split('}')[0];
                return attribute.strip();
              };
            }
            else if (value === '') {
              f = function(element, attribute) {
                attribute = element.getAttribute(attribute);
                if (!attribute) return null;
                return attribute.strip();
              };
            }
            el = null;
            return f;
          })(),
          _flag: function(element, attribute) {
            return $(element).hasAttribute(attribute) ? attribute : null;
          },
          style: function(element) {
            return element.style.cssText.toLowerCase();
          },
          title: function(element) {
            return element.title;
          }
        }
      }
    }
  })();

  Element._attributeTranslations.write = {
    names: Object.extend({
      cellpadding: 'cellPadding',
      cellspacing: 'cellSpacing'
    }, Element._attributeTranslations.read.names),
    values: {
      checked: function(element, value) {
        element.checked = !!value;
      },

      style: function(element, value) {
        element.style.cssText = value ? value : '';
      }
    }
  };

  Element._attributeTranslations.has = {};

  $w('colSpan rowSpan vAlign dateTime accessKey tabIndex ' +
      'encType maxLength readOnly longDesc frameBorder').each(function(attr) {
    Element._attributeTranslations.write.names[attr.toLowerCase()] = attr;
    Element._attributeTranslations.has[attr.toLowerCase()] = attr;
  });

  (function(v) {
    Object.extend(v, {
      href:        v._getAttr2,
      src:         v._getAttr2,
      type:        v._getAttr,
      action:      v._getAttrNode,
      disabled:    v._flag,
      checked:     v._flag,
      readonly:    v._flag,
      multiple:    v._flag,
      onload:      v._getEv,
      onunload:    v._getEv,
      onclick:     v._getEv,
      ondblclick:  v._getEv,
      onmousedown: v._getEv,
      onmouseup:   v._getEv,
      onmouseover: v._getEv,
      onmousemove: v._getEv,
      onmouseout:  v._getEv,
      onfocus:     v._getEv,
      onblur:      v._getEv,
      onkeypress:  v._getEv,
      onkeydown:   v._getEv,
      onkeyup:     v._getEv,
      onsubmit:    v._getEv,
      onreset:     v._getEv,
      onselect:    v._getEv,
      onchange:    v._getEv
    });
  })(Element._attributeTranslations.read.values);

  if (Prototype.BrowserFeatures.ElementExtensions) {
    (function() {
      function _descendants(element) {
        var nodes = element.getElementsByTagName('*'), results = [];
        for (var i = 0, node; node = nodes[i]; i++)
          if (node.tagName !== "!") // Filter out comment nodes.
            results.push(node);
        return results;
      }

      Element.Methods.down = function(element, expression, index) {
        element = $(element);
        if (arguments.length == 1) return element.firstDescendant();
        return Object.isNumber(expression) ? _descendants(element)[expression] :
          Element.select(element, expression)[index || 0];
      }
    })();
  }

}

else if (Prototype.Browser.Gecko && /rv:1\.8\.0/.test(navigator.userAgent)) {
  Element.Methods.setOpacity = function(element, value) {
    element = $(element);
    element.style.opacity = (value == 1) ? 0.999999 :
      (value === '') ? '' : (value < 0.00001) ? 0 : value;
    return element;
  };
}

else if (Prototype.Browser.WebKit) {
  Element.Methods.setOpacity = function(element, value) {
    element = $(element);
    element.style.opacity = (value == 1 || value === '') ? '' :
      (value < 0.00001) ? 0 : value;

    if (value == 1)
      if (element.tagName.toUpperCase() == 'IMG' && element.width) {
        element.width++; element.width--;
      } else try {
        var n = document.createTextNode(' ');
        element.appendChild(n);
        element.removeChild(n);
      } catch (e) { }

    return element;
  };
}

if ('outerHTML' in document.documentElement) {
  Element.Methods.replace = function(element, content) {
    element = $(element);

    if (content && content.toElement) content = content.toElement();
    if (Object.isElement(content)) {
      element.parentNode.replaceChild(content, element);
      return element;
    }

    content = Object.toHTML(content);
    var parent = element.parentNode, tagName = parent.tagName.toUpperCase();

    if (Element._insertionTranslations.tags[tagName]) {
      var nextSibling = element.next(),
          fragments = Element._getContentFromAnonymousElement(tagName, content.stripScripts());
      parent.removeChild(element);
      if (nextSibling)
        fragments.each(function(node) { parent.insertBefore(node, nextSibling) });
      else
        fragments.each(function(node) { parent.appendChild(node) });
    }
    else element.outerHTML = content.stripScripts();

    content.evalScripts.bind(content).defer();
    return element;
  };
}

Element._returnOffset = function(l, t) {
  var result = [l, t];
  result.left = l;
  result.top = t;
  return result;
};

Element._getContentFromAnonymousElement = function(tagName, html, force) {
  var div = new Element('div'),
      t = Element._insertionTranslations.tags[tagName];

  var workaround = false;
  if (t) workaround = true;
  else if (force) {
    workaround = true;
    t = ['', '', 0];
  }

  if (workaround) {
    div.innerHTML = '&nbsp;' + t[0] + html + t[1];
    div.removeChild(div.firstChild);
    for (var i = t[2]; i--; ) {
      div = div.firstChild;
    }
  }
  else {
    div.innerHTML = html;
  }
  return $A(div.childNodes);
};

Element._insertionTranslations = {
  before: function(element, node) {
    element.parentNode.insertBefore(node, element);
  },
  top: function(element, node) {
    element.insertBefore(node, element.firstChild);
  },
  bottom: function(element, node) {
    element.appendChild(node);
  },
  after: function(element, node) {
    element.parentNode.insertBefore(node, element.nextSibling);
  },
  tags: {
    TABLE:  ['<table>',                '</table>',                   1],
    TBODY:  ['<table><tbody>',         '</tbody></table>',           2],
    TR:     ['<table><tbody><tr>',     '</tr></tbody></table>',      3],
    TD:     ['<table><tbody><tr><td>', '</td></tr></tbody></table>', 4],
    SELECT: ['<select>',               '</select>',                  1]
  }
};

(function() {
  var tags = Element._insertionTranslations.tags;
  Object.extend(tags, {
    THEAD: tags.TBODY,
    TFOOT: tags.TBODY,
    TH:    tags.TD
  });
})();

Element.Methods.Simulated = {
  hasAttribute: function(element, attribute) {
    attribute = Element._attributeTranslations.has[attribute] || attribute;
    var node = $(element).getAttributeNode(attribute);
    return !!(node && node.specified);
  }
};

Element.Methods.ByTag = { };

Object.extend(Element, Element.Methods);

(function(div) {

  if (!Prototype.BrowserFeatures.ElementExtensions && div['__proto__']) {
    window.HTMLElement = { };
    window.HTMLElement.prototype = div['__proto__'];
    Prototype.BrowserFeatures.ElementExtensions = true;
  }

  div = null;

})(document.createElement('div'));

Element.extend = (function() {

  function checkDeficiency(tagName) {
    if (typeof window.Element != 'undefined') {
      var proto = window.Element.prototype;
      if (proto) {
        var id = '_' + (Math.random()+'').slice(2),
            el = document.createElement(tagName);
        proto[id] = 'x';
        var isBuggy = (el[id] !== 'x');
        delete proto[id];
        el = null;
        return isBuggy;
      }
    }
    return false;
  }

  function extendElementWith(element, methods) {
    for (var property in methods) {
      var value = methods[property];
      if (Object.isFunction(value) && !(property in element))
        element[property] = value.methodize();
    }
  }

  var HTMLOBJECTELEMENT_PROTOTYPE_BUGGY = checkDeficiency('object');

  if (Prototype.BrowserFeatures.SpecificElementExtensions) {
    if (HTMLOBJECTELEMENT_PROTOTYPE_BUGGY) {
      return function(element) {
        if (element && typeof element._extendedByPrototype == 'undefined') {
          var t = element.tagName;
          if (t && (/^(?:object|applet|embed)$/i.test(t))) {
            extendElementWith(element, Element.Methods);
            extendElementWith(element, Element.Methods.Simulated);
            extendElementWith(element, Element.Methods.ByTag[t.toUpperCase()]);
          }
        }
        return element;
      }
    }
    return Prototype.K;
  }

  var Methods = { }, ByTag = Element.Methods.ByTag;

  var extend = Object.extend(function(element) {
    if (!element || typeof element._extendedByPrototype != 'undefined' ||
        element.nodeType != 1 || element == window) return element;

    var methods = Object.clone(Methods),
        tagName = element.tagName.toUpperCase();

    if (ByTag[tagName]) Object.extend(methods, ByTag[tagName]);

    extendElementWith(element, methods);

    element._extendedByPrototype = Prototype.emptyFunction;
    return element;

  }, {
    refresh: function() {
      if (!Prototype.BrowserFeatures.ElementExtensions) {
        Object.extend(Methods, Element.Methods);
        Object.extend(Methods, Element.Methods.Simulated);
      }
    }
  });

  extend.refresh();
  return extend;
})();

if (document.documentElement.hasAttribute) {
  Element.hasAttribute = function(element, attribute) {
    return element.hasAttribute(attribute);
  };
}
else {
  Element.hasAttribute = Element.Methods.Simulated.hasAttribute;
}

Element.addMethods = function(methods) {
  var F = Prototype.BrowserFeatures, T = Element.Methods.ByTag;

  if (!methods) {
    Object.extend(Form, Form.Methods);
    Object.extend(Form.Element, Form.Element.Methods);
    Object.extend(Element.Methods.ByTag, {
      "FORM":     Object.clone(Form.Methods),
      "INPUT":    Object.clone(Form.Element.Methods),
      "SELECT":   Object.clone(Form.Element.Methods),
      "TEXTAREA": Object.clone(Form.Element.Methods),
      "BUTTON":   Object.clone(Form.Element.Methods)
    });
  }

  if (arguments.length == 2) {
    var tagName = methods;
    methods = arguments[1];
  }

  if (!tagName) Object.extend(Element.Methods, methods || { });
  else {
    if (Object.isArray(tagName)) tagName.each(extend);
    else extend(tagName);
  }

  function extend(tagName) {
    tagName = tagName.toUpperCase();
    if (!Element.Methods.ByTag[tagName])
      Element.Methods.ByTag[tagName] = { };
    Object.extend(Element.Methods.ByTag[tagName], methods);
  }

  function copy(methods, destination, onlyIfAbsent) {
    onlyIfAbsent = onlyIfAbsent || false;
    for (var property in methods) {
      var value = methods[property];
      if (!Object.isFunction(value)) continue;
      if (!onlyIfAbsent || !(property in destination))
        destination[property] = value.methodize();
    }
  }

  function findDOMClass(tagName) {
    var klass;
    var trans = {
      "OPTGROUP": "OptGroup", "TEXTAREA": "TextArea", "P": "Paragraph",
      "FIELDSET": "FieldSet", "UL": "UList", "OL": "OList", "DL": "DList",
      "DIR": "Directory", "H1": "Heading", "H2": "Heading", "H3": "Heading",
      "H4": "Heading", "H5": "Heading", "H6": "Heading", "Q": "Quote",
      "INS": "Mod", "DEL": "Mod", "A": "Anchor", "IMG": "Image", "CAPTION":
      "TableCaption", "COL": "TableCol", "COLGROUP": "TableCol", "THEAD":
      "TableSection", "TFOOT": "TableSection", "TBODY": "TableSection", "TR":
      "TableRow", "TH": "TableCell", "TD": "TableCell", "FRAMESET":
      "FrameSet", "IFRAME": "IFrame"
    };
    if (trans[tagName]) klass = 'HTML' + trans[tagName] + 'Element';
    if (window[klass]) return window[klass];
    klass = 'HTML' + tagName + 'Element';
    if (window[klass]) return window[klass];
    klass = 'HTML' + tagName.capitalize() + 'Element';
    if (window[klass]) return window[klass];

    var element = document.createElement(tagName),
        proto = element['__proto__'] || element.constructor.prototype;

    element = null;
    return proto;
  }

  var elementPrototype = window.HTMLElement ? HTMLElement.prototype :
   Element.prototype;

  if (F.ElementExtensions) {
    copy(Element.Methods, elementPrototype);
    copy(Element.Methods.Simulated, elementPrototype, true);
  }

  if (F.SpecificElementExtensions) {
    for (var tag in Element.Methods.ByTag) {
      var klass = findDOMClass(tag);
      if (Object.isUndefined(klass)) continue;
      copy(T[tag], klass.prototype);
    }
  }

  Object.extend(Element, Element.Methods);
  delete Element.ByTag;

  if (Element.extend.refresh) Element.extend.refresh();
  Element.cache = { };
};


document.viewport = {

  getDimensions: function() {
    return { width: this.getWidth(), height: this.getHeight() };
  },

  getScrollOffsets: function() {
    return Element._returnOffset(
      window.pageXOffset || document.documentElement.scrollLeft || document.body.scrollLeft,
      window.pageYOffset || document.documentElement.scrollTop  || document.body.scrollTop);
  }
};

(function(viewport) {
  var B = Prototype.Browser, doc = document, element, property = {};

  function getRootElement() {
    if (B.WebKit && !doc.evaluate)
      return document;

    if (B.Opera && window.parseFloat(window.opera.version()) < 9.5)
      return document.body;

    return document.documentElement;
  }

  function define(D) {
    if (!element) element = getRootElement();

    property[D] = 'client' + D;

    viewport['get' + D] = function() { return element[property[D]] };
    return viewport['get' + D]();
  }

  viewport.getWidth  = define.curry('Width');

  viewport.getHeight = define.curry('Height');
})(document.viewport);


Element.Storage = {
  UID: 1
};

Element.addMethods({
  getStorage: function(element) {
    if (!(element = $(element))) return;

    var uid;
    if (element === window) {
      uid = 0;
    } else {
      if (typeof element._prototypeUID === "undefined")
        element._prototypeUID = Element.Storage.UID++;
      uid = element._prototypeUID;
    }

    if (!Element.Storage[uid])
      Element.Storage[uid] = $H();

    return Element.Storage[uid];
  },

  store: function(element, key, value) {
    if (!(element = $(element))) return;

    if (arguments.length === 2) {
      Element.getStorage(element).update(key);
    } else {
      Element.getStorage(element).set(key, value);
    }

    return element;
  },

  retrieve: function(element, key, defaultValue) {
    if (!(element = $(element))) return;
    var hash = Element.getStorage(element), value = hash.get(key);

    if (Object.isUndefined(value)) {
      hash.set(key, defaultValue);
      value = defaultValue;
    }

    return value;
  },

  clone: function(element, deep) {
    if (!(element = $(element))) return;
    var clone = element.cloneNode(deep);
    clone._prototypeUID = void 0;
    if (deep) {
      var descendants = Element.select(clone, '*'),
          i = descendants.length;
      while (i--) {
        descendants[i]._prototypeUID = void 0;
      }
    }
    return Element.extend(clone);
  },

  purge: function(element) {
    if (!(element = $(element))) return;
    var purgeElement = Element._purgeElement;

    purgeElement(element);

    var descendants = element.getElementsByTagName('*'),
     i = descendants.length;

    while (i--) purgeElement(descendants[i]);

    return null;
  }
});

(function() {

  function toDecimal(pctString) {
    var match = pctString.match(/^(\d+)%?$/i);
    if (!match) return null;
    return (Number(match[1]) / 100);
  }

  function getPixelValue(value, property, context) {
    var element = null;
    if (Object.isElement(value)) {
      element = value;
      value = element.getStyle(property);
    }

    if (value === null) {
      return null;
    }

    if ((/^(?:-)?\d+(\.\d+)?(px)?$/i).test(value)) {
      return window.parseFloat(value);
    }

    var isPercentage = value.include('%'), isViewport = (context === document.viewport);

    if (/\d/.test(value) && element && element.runtimeStyle && !(isPercentage && isViewport)) {
      var style = element.style.left, rStyle = element.runtimeStyle.left;
      element.runtimeStyle.left = element.currentStyle.left;
      element.style.left = value || 0;
      value = element.style.pixelLeft;
      element.style.left = style;
      element.runtimeStyle.left = rStyle;

      return value;
    }

    if (element && isPercentage) {
      context = context || element.parentNode;
      var decimal = toDecimal(value);
      var whole = null;
      var position = element.getStyle('position');

      var isHorizontal = property.include('left') || property.include('right') ||
       property.include('width');

      var isVertical =  property.include('top') || property.include('bottom') ||
        property.include('height');

      if (context === document.viewport) {
        if (isHorizontal) {
          whole = document.viewport.getWidth();
        } else if (isVertical) {
          whole = document.viewport.getHeight();
        }
      } else {
        if (isHorizontal) {
          whole = $(context).measure('width');
        } else if (isVertical) {
          whole = $(context).measure('height');
        }
      }

      return (whole === null) ? 0 : whole * decimal;
    }

    return 0;
  }

  function toCSSPixels(number) {
    if (Object.isString(number) && number.endsWith('px')) {
      return number;
    }
    return number + 'px';
  }

  function isDisplayed(element) {
    var originalElement = element;
    while (element && element.parentNode) {
      var display = element.getStyle('display');
      if (display === 'none') {
        return false;
      }
      element = $(element.parentNode);
    }
    return true;
  }

  var hasLayout = Prototype.K;
  if ('currentStyle' in document.documentElement) {
    hasLayout = function(element) {
      if (!element.currentStyle.hasLayout) {
        element.style.zoom = 1;
      }
      return element;
    };
  }

  function cssNameFor(key) {
    if (key.include('border')) key = key + '-width';
    return key.camelize();
  }

  Element.Layout = Class.create(Hash, {
    initialize: function($super, element, preCompute) {
      $super();
      this.element = $(element);

      Element.Layout.PROPERTIES.each( function(property) {
        this._set(property, null);
      }, this);

      if (preCompute) {
        this._preComputing = true;
        this._begin();
        Element.Layout.PROPERTIES.each( this._compute, this );
        this._end();
        this._preComputing = false;
      }
    },

    _set: function(property, value) {
      return Hash.prototype.set.call(this, property, value);
    },

    set: function(property, value) {
      throw "Properties of Element.Layout are read-only.";
    },

    get: function($super, property) {
      var value = $super(property);
      return value === null ? this._compute(property) : value;
    },

    _begin: function() {
      if (this._prepared) return;

      var element = this.element;
      if (isDisplayed(element)) {
        this._prepared = true;
        return;
      }

      var originalStyles = {
        position:   element.style.position   || '',
        width:      element.style.width      || '',
        visibility: element.style.visibility || '',
        display:    element.style.display    || ''
      };

      element.store('prototype_original_styles', originalStyles);

      var position = element.getStyle('position'),
       width = element.getStyle('width');

      if (width === "0px" || width === null) {
        element.style.display = 'block';
        width = element.getStyle('width');
      }

      var context = (position === 'fixed') ? document.viewport :
       element.parentNode;

      element.setStyle({
        position:   'absolute',
        visibility: 'hidden',
        display:    'block'
      });

      var positionedWidth = element.getStyle('width');

      var newWidth;
      if (width && (positionedWidth === width)) {
        newWidth = getPixelValue(element, 'width', context);
      } else if (position === 'absolute' || position === 'fixed') {
        newWidth = getPixelValue(element, 'width', context);
      } else {
        var parent = element.parentNode, pLayout = $(parent).getLayout();

        newWidth = pLayout.get('width') -
         this.get('margin-left') -
         this.get('border-left') -
         this.get('padding-left') -
         this.get('padding-right') -
         this.get('border-right') -
         this.get('margin-right');
      }

      element.setStyle({ width: newWidth + 'px' });

      this._prepared = true;
    },

    _end: function() {
      var element = this.element;
      var originalStyles = element.retrieve('prototype_original_styles');
      element.store('prototype_original_styles', null);
      element.setStyle(originalStyles);
      this._prepared = false;
    },

    _compute: function(property) {
      var COMPUTATIONS = Element.Layout.COMPUTATIONS;
      if (!(property in COMPUTATIONS)) {
        throw "Property not found.";
      }

      return this._set(property, COMPUTATIONS[property].call(this, this.element));
    },

    toObject: function() {
      var args = $A(arguments);
      var keys = (args.length === 0) ? Element.Layout.PROPERTIES :
       args.join(' ').split(' ');
      var obj = {};
      keys.each( function(key) {
        if (!Element.Layout.PROPERTIES.include(key)) return;
        var value = this.get(key);
        if (value != null) obj[key] = value;
      }, this);
      return obj;
    },

    toHash: function() {
      var obj = this.toObject.apply(this, arguments);
      return new Hash(obj);
    },

    toCSS: function() {
      var args = $A(arguments);
      var keys = (args.length === 0) ? Element.Layout.PROPERTIES :
       args.join(' ').split(' ');
      var css = {};

      keys.each( function(key) {
        if (!Element.Layout.PROPERTIES.include(key)) return;
        if (Element.Layout.COMPOSITE_PROPERTIES.include(key)) return;

        var value = this.get(key);
        if (value != null) css[cssNameFor(key)] = value + 'px';
      }, this);
      return css;
    },

    inspect: function() {
      return "#<Element.Layout>";
    }
  });

  Object.extend(Element.Layout, {
    PROPERTIES: $w('height width top left right bottom border-left border-right border-top border-bottom padding-left padding-right padding-top padding-bottom margin-top margin-bottom margin-left margin-right padding-box-width padding-box-height border-box-width border-box-height margin-box-width margin-box-height'),

    COMPOSITE_PROPERTIES: $w('padding-box-width padding-box-height margin-box-width margin-box-height border-box-width border-box-height'),

    COMPUTATIONS: {
      'height': function(element) {
        if (!this._preComputing) this._begin();

        var bHeight = this.get('border-box-height');
        if (bHeight <= 0) {
          if (!this._preComputing) this._end();
          return 0;
        }

        var bTop = this.get('border-top'),
         bBottom = this.get('border-bottom');

        var pTop = this.get('padding-top'),
         pBottom = this.get('padding-bottom');

        if (!this._preComputing) this._end();

        return bHeight - bTop - bBottom - pTop - pBottom;
      },

      'width': function(element) {
        if (!this._preComputing) this._begin();

        var bWidth = this.get('border-box-width');
        if (bWidth <= 0) {
          if (!this._preComputing) this._end();
          return 0;
        }

        var bLeft = this.get('border-left'),
         bRight = this.get('border-right');

        var pLeft = this.get('padding-left'),
         pRight = this.get('padding-right');

        if (!this._preComputing) this._end();

        return bWidth - bLeft - bRight - pLeft - pRight;
      },

      'padding-box-height': function(element) {
        var height = this.get('height'),
         pTop = this.get('padding-top'),
         pBottom = this.get('padding-bottom');

        return height + pTop + pBottom;
      },

      'padding-box-width': function(element) {
        var width = this.get('width'),
         pLeft = this.get('padding-left'),
         pRight = this.get('padding-right');

        return width + pLeft + pRight;
      },

      'border-box-height': function(element) {
        if (!this._preComputing) this._begin();
        var height = element.offsetHeight;
        if (!this._preComputing) this._end();
        return height;
      },

      'border-box-width': function(element) {
        if (!this._preComputing) this._begin();
        var width = element.offsetWidth;
        if (!this._preComputing) this._end();
        return width;
      },

      'margin-box-height': function(element) {
        var bHeight = this.get('border-box-height'),
         mTop = this.get('margin-top'),
         mBottom = this.get('margin-bottom');

        if (bHeight <= 0) return 0;

        return bHeight + mTop + mBottom;
      },

      'margin-box-width': function(element) {
        var bWidth = this.get('border-box-width'),
         mLeft = this.get('margin-left'),
         mRight = this.get('margin-right');

        if (bWidth <= 0) return 0;

        return bWidth + mLeft + mRight;
      },

      'top': function(element) {
        var offset = element.positionedOffset();
        return offset.top;
      },

      'bottom': function(element) {
        var offset = element.positionedOffset(),
         parent = element.getOffsetParent(),
         pHeight = parent.measure('height');

        var mHeight = this.get('border-box-height');

        return pHeight - mHeight - offset.top;
      },

      'left': function(element) {
        var offset = element.positionedOffset();
        return offset.left;
      },

      'right': function(element) {
        var offset = element.positionedOffset(),
         parent = element.getOffsetParent(),
         pWidth = parent.measure('width');

        var mWidth = this.get('border-box-width');

        return pWidth - mWidth - offset.left;
      },

      'padding-top': function(element) {
        return getPixelValue(element, 'paddingTop');
      },

      'padding-bottom': function(element) {
        return getPixelValue(element, 'paddingBottom');
      },

      'padding-left': function(element) {
        return getPixelValue(element, 'paddingLeft');
      },

      'padding-right': function(element) {
        return getPixelValue(element, 'paddingRight');
      },

      'border-top': function(element) {
        return getPixelValue(element, 'borderTopWidth');
      },

      'border-bottom': function(element) {
        return getPixelValue(element, 'borderBottomWidth');
      },

      'border-left': function(element) {
        return getPixelValue(element, 'borderLeftWidth');
      },

      'border-right': function(element) {
        return getPixelValue(element, 'borderRightWidth');
      },

      'margin-top': function(element) {
        return getPixelValue(element, 'marginTop');
      },

      'margin-bottom': function(element) {
        return getPixelValue(element, 'marginBottom');
      },

      'margin-left': function(element) {
        return getPixelValue(element, 'marginLeft');
      },

      'margin-right': function(element) {
        return getPixelValue(element, 'marginRight');
      }
    }
  });

  if ('getBoundingClientRect' in document.documentElement) {
    Object.extend(Element.Layout.COMPUTATIONS, {
      'right': function(element) {
        var parent = hasLayout(element.getOffsetParent());
        var rect = element.getBoundingClientRect(),
         pRect = parent.getBoundingClientRect();

        return (pRect.right - rect.right).round();
      },

      'bottom': function(element) {
        var parent = hasLayout(element.getOffsetParent());
        var rect = element.getBoundingClientRect(),
         pRect = parent.getBoundingClientRect();

        return (pRect.bottom - rect.bottom).round();
      }
    });
  }

  Element.Offset = Class.create({
    initialize: function(left, top) {
      this.left = left.round();
      this.top  = top.round();

      this[0] = this.left;
      this[1] = this.top;
    },

    relativeTo: function(offset) {
      return new Element.Offset(
        this.left - offset.left,
        this.top  - offset.top
      );
    },

    inspect: function() {
      return "#<Element.Offset left: #{left} top: #{top}>".interpolate(this);
    },

    toString: function() {
      return "[#{left}, #{top}]".interpolate(this);
    },

    toArray: function() {
      return [this.left, this.top];
    }
  });

  function getLayout(element, preCompute) {
    return new Element.Layout(element, preCompute);
  }

  function measure(element, property) {
    return $(element).getLayout().get(property);
  }

  function getDimensions(element) {
    element = $(element);
    var display = Element.getStyle(element, 'display');

    if (display && display !== 'none') {
      return { width: element.offsetWidth, height: element.offsetHeight };
    }

    var style = element.style;
    var originalStyles = {
      visibility: style.visibility,
      position:   style.position,
      display:    style.display
    };

    var newStyles = {
      visibility: 'hidden',
      display:    'block'
    };

    if (originalStyles.position !== 'fixed')
      newStyles.position = 'absolute';

    Element.setStyle(element, newStyles);

    var dimensions = {
      width:  element.offsetWidth,
      height: element.offsetHeight
    };

    Element.setStyle(element, originalStyles);

    return dimensions;
  }

  function getOffsetParent(element) {
    element = $(element);

    if (isDocument(element) || isDetached(element) || isBody(element) || isHtml(element))
      return $(document.body);

    var isInline = (Element.getStyle(element, 'display') === 'inline');
    if (!isInline && element.offsetParent) return $(element.offsetParent);

    while ((element = element.parentNode) && element !== document.body) {
      if (Element.getStyle(element, 'position') !== 'static') {
        return isHtml(element) ? $(document.body) : $(element);
      }
    }

    return $(document.body);
  }


  function cumulativeOffset(element) {
    element = $(element);
    var valueT = 0, valueL = 0;
    if (element.parentNode) {
      do {
        valueT += element.offsetTop  || 0;
        valueL += element.offsetLeft || 0;
        element = element.offsetParent;
      } while (element);
    }
    return new Element.Offset(valueL, valueT);
  }

  function positionedOffset(element) {
    element = $(element);

    var layout = element.getLayout();

    var valueT = 0, valueL = 0;
    do {
      valueT += element.offsetTop  || 0;
      valueL += element.offsetLeft || 0;
      element = element.offsetParent;
      if (element) {
        if (isBody(element)) break;
        var p = Element.getStyle(element, 'position');
        if (p !== 'static') break;
      }
    } while (element);

    valueL -= layout.get('margin-top');
    valueT -= layout.get('margin-left');

    return new Element.Offset(valueL, valueT);
  }

  function cumulativeScrollOffset(element) {
    var valueT = 0, valueL = 0;
    do {
      valueT += element.scrollTop  || 0;
      valueL += element.scrollLeft || 0;
      element = element.parentNode;
    } while (element);
    return new Element.Offset(valueL, valueT);
  }

  function viewportOffset(forElement) {
    element = $(element);
    var valueT = 0, valueL = 0, docBody = document.body;

    var element = forElement;
    do {
      valueT += element.offsetTop  || 0;
      valueL += element.offsetLeft || 0;
      if (element.offsetParent == docBody &&
        Element.getStyle(element, 'position') == 'absolute') break;
    } while (element = element.offsetParent);

    element = forElement;
    do {
      if (element != docBody) {
        valueT -= element.scrollTop  || 0;
        valueL -= element.scrollLeft || 0;
      }
    } while (element = element.parentNode);
    return new Element.Offset(valueL, valueT);
  }

  function absolutize(element) {
    element = $(element);

    if (Element.getStyle(element, 'position') === 'absolute') {
      return element;
    }

    var offsetParent = getOffsetParent(element);
    var eOffset = element.viewportOffset(),
     pOffset = offsetParent.viewportOffset();

    var offset = eOffset.relativeTo(pOffset);
    var layout = element.getLayout();

    element.store('prototype_absolutize_original_styles', {
      left:   element.getStyle('left'),
      top:    element.getStyle('top'),
      width:  element.getStyle('width'),
      height: element.getStyle('height')
    });

    element.setStyle({
      position: 'absolute',
      top:    offset.top + 'px',
      left:   offset.left + 'px',
      width:  layout.get('width') + 'px',
      height: layout.get('height') + 'px'
    });

    return element;
  }

  function relativize(element) {
    element = $(element);
    if (Element.getStyle(element, 'position') === 'relative') {
      return element;
    }

    var originalStyles =
     element.retrieve('prototype_absolutize_original_styles');

    if (originalStyles) element.setStyle(originalStyles);
    return element;
  }

  if (Prototype.Browser.IE) {
    getOffsetParent = getOffsetParent.wrap(
      function(proceed, element) {
        element = $(element);

        if (isDocument(element) || isDetached(element) || isBody(element) || isHtml(element))
          return $(document.body);

        var position = element.getStyle('position');
        if (position !== 'static') return proceed(element);

        element.setStyle({ position: 'relative' });
        var value = proceed(element);
        element.setStyle({ position: position });
        return value;
      }
    );

    positionedOffset = positionedOffset.wrap(function(proceed, element) {
      element = $(element);
      if (!element.parentNode) return new Element.Offset(0, 0);
      var position = element.getStyle('position');
      if (position !== 'static') return proceed(element);

      var offsetParent = element.getOffsetParent();
      if (offsetParent && offsetParent.getStyle('position') === 'fixed')
        hasLayout(offsetParent);

      element.setStyle({ position: 'relative' });
      var value = proceed(element);
      element.setStyle({ position: position });
      return value;
    });
  } else if (Prototype.Browser.Webkit) {
    cumulativeOffset = function(element) {
      element = $(element);
      var valueT = 0, valueL = 0;
      do {
        valueT += element.offsetTop  || 0;
        valueL += element.offsetLeft || 0;
        if (element.offsetParent == document.body)
          if (Element.getStyle(element, 'position') == 'absolute') break;

        element = element.offsetParent;
      } while (element);

      return new Element.Offset(valueL, valueT);
    };
  }


  Element.addMethods({
    getLayout:              getLayout,
    measure:                measure,
    getDimensions:          getDimensions,
    getOffsetParent:        getOffsetParent,
    cumulativeOffset:       cumulativeOffset,
    positionedOffset:       positionedOffset,
    cumulativeScrollOffset: cumulativeScrollOffset,
    viewportOffset:         viewportOffset,
    absolutize:             absolutize,
    relativize:             relativize
  });

  function isBody(element) {
    return element.nodeName.toUpperCase() === 'BODY';
  }

  function isHtml(element) {
    return element.nodeName.toUpperCase() === 'HTML';
  }

  function isDocument(element) {
    return element.nodeType === Node.DOCUMENT_NODE;
  }

  function isDetached(element) {
    return element !== document.body &&
     !Element.descendantOf(element, document.body);
  }

  if ('getBoundingClientRect' in document.documentElement) {
    Element.addMethods({
      viewportOffset: function(element) {
        element = $(element);
        if (isDetached(element)) return new Element.Offset(0, 0);

        var rect = element.getBoundingClientRect(),
         docEl = document.documentElement;
        return new Element.Offset(rect.left - docEl.clientLeft,
         rect.top - docEl.clientTop);
      }
    });
  }
})();
window.$$ = function() {
  var expression = $A(arguments).join(', ');
  return Prototype.Selector.select(expression, document);
};

Prototype.Selector = (function() {

  function select() {
    throw new Error('Method "Prototype.Selector.select" must be defined.');
  }

  function match() {
    throw new Error('Method "Prototype.Selector.match" must be defined.');
  }

  function find(elements, expression, index) {
    index = index || 0;
    var match = Prototype.Selector.match, length = elements.length, matchIndex = 0, i;

    for (i = 0; i < length; i++) {
      if (match(elements[i], expression) && index == matchIndex++) {
        return Element.extend(elements[i]);
      }
    }
  }

  function extendElements(elements) {
    for (var i = 0, length = elements.length; i < length; i++) {
      Element.extend(elements[i]);
    }
    return elements;
  }


  var K = Prototype.K;

  return {
    select: select,
    match: match,
    find: find,
    extendElements: (Element.extend === K) ? K : extendElements,
    extendElement: Element.extend
  };
})();
Prototype._original_property = window.Sizzle;
/*!
 * Sizzle CSS Selector Engine - v1.0
 *  Copyright 2009, The Dojo Foundation
 *  Released under the MIT, BSD, and GPL Licenses.
 *  More information: http://sizzlejs.com/
 */
(function(){

var chunker = /((?:\((?:\([^()]+\)|[^()]+)+\)|\[(?:\[[^[\]]*\]|['"][^'"]*['"]|[^[\]'"]+)+\]|\\.|[^ >+~,(\[\\]+)+|[>+~])(\s*,\s*)?((?:.|\r|\n)*)/g,
	done = 0,
	toString = Object.prototype.toString,
	hasDuplicate = false,
	baseHasDuplicate = true;

[0, 0].sort(function(){
	baseHasDuplicate = false;
	return 0;
});

var Sizzle = function(selector, context, results, seed) {
	results = results || [];
	var origContext = context = context || document;

	if ( context.nodeType !== 1 && context.nodeType !== 9 ) {
		return [];
	}

	if ( !selector || typeof selector !== "string" ) {
		return results;
	}

	var parts = [], m, set, checkSet, check, mode, extra, prune = true, contextXML = isXML(context),
		soFar = selector;

	while ( (chunker.exec(""), m = chunker.exec(soFar)) !== null ) {
		soFar = m[3];

		parts.push( m[1] );

		if ( m[2] ) {
			extra = m[3];
			break;
		}
	}

	if ( parts.length > 1 && origPOS.exec( selector ) ) {
		if ( parts.length === 2 && Expr.relative[ parts[0] ] ) {
			set = posProcess( parts[0] + parts[1], context );
		} else {
			set = Expr.relative[ parts[0] ] ?
				[ context ] :
				Sizzle( parts.shift(), context );

			while ( parts.length ) {
				selector = parts.shift();

				if ( Expr.relative[ selector ] )
					selector += parts.shift();

				set = posProcess( selector, set );
			}
		}
	} else {
		if ( !seed && parts.length > 1 && context.nodeType === 9 && !contextXML &&
				Expr.match.ID.test(parts[0]) && !Expr.match.ID.test(parts[parts.length - 1]) ) {
			var ret = Sizzle.find( parts.shift(), context, contextXML );
			context = ret.expr ? Sizzle.filter( ret.expr, ret.set )[0] : ret.set[0];
		}

		if ( context ) {
			var ret = seed ?
				{ expr: parts.pop(), set: makeArray(seed) } :
				Sizzle.find( parts.pop(), parts.length === 1 && (parts[0] === "~" || parts[0] === "+") && context.parentNode ? context.parentNode : context, contextXML );
			set = ret.expr ? Sizzle.filter( ret.expr, ret.set ) : ret.set;

			if ( parts.length > 0 ) {
				checkSet = makeArray(set);
			} else {
				prune = false;
			}

			while ( parts.length ) {
				var cur = parts.pop(), pop = cur;

				if ( !Expr.relative[ cur ] ) {
					cur = "";
				} else {
					pop = parts.pop();
				}

				if ( pop == null ) {
					pop = context;
				}

				Expr.relative[ cur ]( checkSet, pop, contextXML );
			}
		} else {
			checkSet = parts = [];
		}
	}

	if ( !checkSet ) {
		checkSet = set;
	}

	if ( !checkSet ) {
		throw "Syntax error, unrecognized expression: " + (cur || selector);
	}

	if ( toString.call(checkSet) === "[object Array]" ) {
		if ( !prune ) {
			results.push.apply( results, checkSet );
		} else if ( context && context.nodeType === 1 ) {
			for ( var i = 0; checkSet[i] != null; i++ ) {
				if ( checkSet[i] && (checkSet[i] === true || checkSet[i].nodeType === 1 && contains(context, checkSet[i])) ) {
					results.push( set[i] );
				}
			}
		} else {
			for ( var i = 0; checkSet[i] != null; i++ ) {
				if ( checkSet[i] && checkSet[i].nodeType === 1 ) {
					results.push( set[i] );
				}
			}
		}
	} else {
		makeArray( checkSet, results );
	}

	if ( extra ) {
		Sizzle( extra, origContext, results, seed );
		Sizzle.uniqueSort( results );
	}

	return results;
};

Sizzle.uniqueSort = function(results){
	if ( sortOrder ) {
		hasDuplicate = baseHasDuplicate;
		results.sort(sortOrder);

		if ( hasDuplicate ) {
			for ( var i = 1; i < results.length; i++ ) {
				if ( results[i] === results[i-1] ) {
					results.splice(i--, 1);
				}
			}
		}
	}

	return results;
};

Sizzle.matches = function(expr, set){
	return Sizzle(expr, null, null, set);
};

Sizzle.find = function(expr, context, isXML){
	var set, match;

	if ( !expr ) {
		return [];
	}

	for ( var i = 0, l = Expr.order.length; i < l; i++ ) {
		var type = Expr.order[i], match;

		if ( (match = Expr.leftMatch[ type ].exec( expr )) ) {
			var left = match[1];
			match.splice(1,1);

			if ( left.substr( left.length - 1 ) !== "\\" ) {
				match[1] = (match[1] || "").replace(/\\/g, "");
				set = Expr.find[ type ]( match, context, isXML );
				if ( set != null ) {
					expr = expr.replace( Expr.match[ type ], "" );
					break;
				}
			}
		}
	}

	if ( !set ) {
		set = context.getElementsByTagName("*");
	}

	return {set: set, expr: expr};
};

Sizzle.filter = function(expr, set, inplace, not){
	var old = expr, result = [], curLoop = set, match, anyFound,
		isXMLFilter = set && set[0] && isXML(set[0]);

	while ( expr && set.length ) {
		for ( var type in Expr.filter ) {
			if ( (match = Expr.match[ type ].exec( expr )) != null ) {
				var filter = Expr.filter[ type ], found, item;
				anyFound = false;

				if ( curLoop == result ) {
					result = [];
				}

				if ( Expr.preFilter[ type ] ) {
					match = Expr.preFilter[ type ]( match, curLoop, inplace, result, not, isXMLFilter );

					if ( !match ) {
						anyFound = found = true;
					} else if ( match === true ) {
						continue;
					}
				}

				if ( match ) {
					for ( var i = 0; (item = curLoop[i]) != null; i++ ) {
						if ( item ) {
							found = filter( item, match, i, curLoop );
							var pass = not ^ !!found;

							if ( inplace && found != null ) {
								if ( pass ) {
									anyFound = true;
								} else {
									curLoop[i] = false;
								}
							} else if ( pass ) {
								result.push( item );
								anyFound = true;
							}
						}
					}
				}

				if ( found !== undefined ) {
					if ( !inplace ) {
						curLoop = result;
					}

					expr = expr.replace( Expr.match[ type ], "" );

					if ( !anyFound ) {
						return [];
					}

					break;
				}
			}
		}

		if ( expr == old ) {
			if ( anyFound == null ) {
				throw "Syntax error, unrecognized expression: " + expr;
			} else {
				break;
			}
		}

		old = expr;
	}

	return curLoop;
};

var Expr = Sizzle.selectors = {
	order: [ "ID", "NAME", "TAG" ],
	match: {
		ID: /#((?:[\w\u00c0-\uFFFF-]|\\.)+)/,
		CLASS: /\.((?:[\w\u00c0-\uFFFF-]|\\.)+)/,
		NAME: /\[name=['"]*((?:[\w\u00c0-\uFFFF-]|\\.)+)['"]*\]/,
		ATTR: /\[\s*((?:[\w\u00c0-\uFFFF-]|\\.)+)\s*(?:(\S?=)\s*(['"]*)(.*?)\3|)\s*\]/,
		TAG: /^((?:[\w\u00c0-\uFFFF\*-]|\\.)+)/,
		CHILD: /:(only|nth|last|first)-child(?:\((even|odd|[\dn+-]*)\))?/,
		POS: /:(nth|eq|gt|lt|first|last|even|odd)(?:\((\d*)\))?(?=[^-]|$)/,
		PSEUDO: /:((?:[\w\u00c0-\uFFFF-]|\\.)+)(?:\((['"]*)((?:\([^\)]+\)|[^\2\(\)]*)+)\2\))?/
	},
	leftMatch: {},
	attrMap: {
		"class": "className",
		"for": "htmlFor"
	},
	attrHandle: {
		href: function(elem){
			return elem.getAttribute("href");
		}
	},
	relative: {
		"+": function(checkSet, part, isXML){
			var isPartStr = typeof part === "string",
				isTag = isPartStr && !/\W/.test(part),
				isPartStrNotTag = isPartStr && !isTag;

			if ( isTag && !isXML ) {
				part = part.toUpperCase();
			}

			for ( var i = 0, l = checkSet.length, elem; i < l; i++ ) {
				if ( (elem = checkSet[i]) ) {
					while ( (elem = elem.previousSibling) && elem.nodeType !== 1 ) {}

					checkSet[i] = isPartStrNotTag || elem && elem.nodeName === part ?
						elem || false :
						elem === part;
				}
			}

			if ( isPartStrNotTag ) {
				Sizzle.filter( part, checkSet, true );
			}
		},
		">": function(checkSet, part, isXML){
			var isPartStr = typeof part === "string";

			if ( isPartStr && !/\W/.test(part) ) {
				part = isXML ? part : part.toUpperCase();

				for ( var i = 0, l = checkSet.length; i < l; i++ ) {
					var elem = checkSet[i];
					if ( elem ) {
						var parent = elem.parentNode;
						checkSet[i] = parent.nodeName === part ? parent : false;
					}
				}
			} else {
				for ( var i = 0, l = checkSet.length; i < l; i++ ) {
					var elem = checkSet[i];
					if ( elem ) {
						checkSet[i] = isPartStr ?
							elem.parentNode :
							elem.parentNode === part;
					}
				}

				if ( isPartStr ) {
					Sizzle.filter( part, checkSet, true );
				}
			}
		},
		"": function(checkSet, part, isXML){
			var doneName = done++, checkFn = dirCheck;

			if ( !/\W/.test(part) ) {
				var nodeCheck = part = isXML ? part : part.toUpperCase();
				checkFn = dirNodeCheck;
			}

			checkFn("parentNode", part, doneName, checkSet, nodeCheck, isXML);
		},
		"~": function(checkSet, part, isXML){
			var doneName = done++, checkFn = dirCheck;

			if ( typeof part === "string" && !/\W/.test(part) ) {
				var nodeCheck = part = isXML ? part : part.toUpperCase();
				checkFn = dirNodeCheck;
			}

			checkFn("previousSibling", part, doneName, checkSet, nodeCheck, isXML);
		}
	},
	find: {
		ID: function(match, context, isXML){
			if ( typeof context.getElementById !== "undefined" && !isXML ) {
				var m = context.getElementById(match[1]);
				return m ? [m] : [];
			}
		},
		NAME: function(match, context, isXML){
			if ( typeof context.getElementsByName !== "undefined" ) {
				var ret = [], results = context.getElementsByName(match[1]);

				for ( var i = 0, l = results.length; i < l; i++ ) {
					if ( results[i].getAttribute("name") === match[1] ) {
						ret.push( results[i] );
					}
				}

				return ret.length === 0 ? null : ret;
			}
		},
		TAG: function(match, context){
			return context.getElementsByTagName(match[1]);
		}
	},
	preFilter: {
		CLASS: function(match, curLoop, inplace, result, not, isXML){
			match = " " + match[1].replace(/\\/g, "") + " ";

			if ( isXML ) {
				return match;
			}

			for ( var i = 0, elem; (elem = curLoop[i]) != null; i++ ) {
				if ( elem ) {
					if ( not ^ (elem.className && (" " + elem.className + " ").indexOf(match) >= 0) ) {
						if ( !inplace )
							result.push( elem );
					} else if ( inplace ) {
						curLoop[i] = false;
					}
				}
			}

			return false;
		},
		ID: function(match){
			return match[1].replace(/\\/g, "");
		},
		TAG: function(match, curLoop){
			for ( var i = 0; curLoop[i] === false; i++ ){}
			return curLoop[i] && isXML(curLoop[i]) ? match[1] : match[1].toUpperCase();
		},
		CHILD: function(match){
			if ( match[1] == "nth" ) {
				var test = /(-?)(\d*)n((?:\+|-)?\d*)/.exec(
					match[2] == "even" && "2n" || match[2] == "odd" && "2n+1" ||
					!/\D/.test( match[2] ) && "0n+" + match[2] || match[2]);

				match[2] = (test[1] + (test[2] || 1)) - 0;
				match[3] = test[3] - 0;
			}

			match[0] = done++;

			return match;
		},
		ATTR: function(match, curLoop, inplace, result, not, isXML){
			var name = match[1].replace(/\\/g, "");

			if ( !isXML && Expr.attrMap[name] ) {
				match[1] = Expr.attrMap[name];
			}

			if ( match[2] === "~=" ) {
				match[4] = " " + match[4] + " ";
			}

			return match;
		},
		PSEUDO: function(match, curLoop, inplace, result, not){
			if ( match[1] === "not" ) {
				if ( ( chunker.exec(match[3]) || "" ).length > 1 || /^\w/.test(match[3]) ) {
					match[3] = Sizzle(match[3], null, null, curLoop);
				} else {
					var ret = Sizzle.filter(match[3], curLoop, inplace, true ^ not);
					if ( !inplace ) {
						result.push.apply( result, ret );
					}
					return false;
				}
			} else if ( Expr.match.POS.test( match[0] ) || Expr.match.CHILD.test( match[0] ) ) {
				return true;
			}

			return match;
		},
		POS: function(match){
			match.unshift( true );
			return match;
		}
	},
	filters: {
		enabled: function(elem){
			return elem.disabled === false && elem.type !== "hidden";
		},
		disabled: function(elem){
			return elem.disabled === true;
		},
		checked: function(elem){
			return elem.checked === true;
		},
		selected: function(elem){
			elem.parentNode.selectedIndex;
			return elem.selected === true;
		},
		parent: function(elem){
			return !!elem.firstChild;
		},
		empty: function(elem){
			return !elem.firstChild;
		},
		has: function(elem, i, match){
			return !!Sizzle( match[3], elem ).length;
		},
		header: function(elem){
			return /h\d/i.test( elem.nodeName );
		},
		text: function(elem){
			return "text" === elem.type;
		},
		radio: function(elem){
			return "radio" === elem.type;
		},
		checkbox: function(elem){
			return "checkbox" === elem.type;
		},
		file: function(elem){
			return "file" === elem.type;
		},
		password: function(elem){
			return "password" === elem.type;
		},
		submit: function(elem){
			return "submit" === elem.type;
		},
		image: function(elem){
			return "image" === elem.type;
		},
		reset: function(elem){
			return "reset" === elem.type;
		},
		button: function(elem){
			return "button" === elem.type || elem.nodeName.toUpperCase() === "BUTTON";
		},
		input: function(elem){
			return /input|select|textarea|button/i.test(elem.nodeName);
		}
	},
	setFilters: {
		first: function(elem, i){
			return i === 0;
		},
		last: function(elem, i, match, array){
			return i === array.length - 1;
		},
		even: function(elem, i){
			return i % 2 === 0;
		},
		odd: function(elem, i){
			return i % 2 === 1;
		},
		lt: function(elem, i, match){
			return i < match[3] - 0;
		},
		gt: function(elem, i, match){
			return i > match[3] - 0;
		},
		nth: function(elem, i, match){
			return match[3] - 0 == i;
		},
		eq: function(elem, i, match){
			return match[3] - 0 == i;
		}
	},
	filter: {
		PSEUDO: function(elem, match, i, array){
			var name = match[1], filter = Expr.filters[ name ];

			if ( filter ) {
				return filter( elem, i, match, array );
			} else if ( name === "contains" ) {
				return (elem.textContent || elem.innerText || "").indexOf(match[3]) >= 0;
			} else if ( name === "not" ) {
				var not = match[3];

				for ( var i = 0, l = not.length; i < l; i++ ) {
					if ( not[i] === elem ) {
						return false;
					}
				}

				return true;
			}
		},
		CHILD: function(elem, match){
			var type = match[1], node = elem;
			switch (type) {
				case 'only':
				case 'first':
					while ( (node = node.previousSibling) )  {
						if ( node.nodeType === 1 ) return false;
					}
					if ( type == 'first') return true;
					node = elem;
				case 'last':
					while ( (node = node.nextSibling) )  {
						if ( node.nodeType === 1 ) return false;
					}
					return true;
				case 'nth':
					var first = match[2], last = match[3];

					if ( first == 1 && last == 0 ) {
						return true;
					}

					var doneName = match[0],
						parent = elem.parentNode;

					if ( parent && (parent.sizcache !== doneName || !elem.nodeIndex) ) {
						var count = 0;
						for ( node = parent.firstChild; node; node = node.nextSibling ) {
							if ( node.nodeType === 1 ) {
								node.nodeIndex = ++count;
							}
						}
						parent.sizcache = doneName;
					}

					var diff = elem.nodeIndex - last;
					if ( first == 0 ) {
						return diff == 0;
					} else {
						return ( diff % first == 0 && diff / first >= 0 );
					}
			}
		},
		ID: function(elem, match){
			return elem.nodeType === 1 && elem.getAttribute("id") === match;
		},
		TAG: function(elem, match){
			return (match === "*" && elem.nodeType === 1) || elem.nodeName === match;
		},
		CLASS: function(elem, match){
			return (" " + (elem.className || elem.getAttribute("class")) + " ")
				.indexOf( match ) > -1;
		},
		ATTR: function(elem, match){
			var name = match[1],
				result = Expr.attrHandle[ name ] ?
					Expr.attrHandle[ name ]( elem ) :
					elem[ name ] != null ?
						elem[ name ] :
						elem.getAttribute( name ),
				value = result + "",
				type = match[2],
				check = match[4];

			return result == null ?
				type === "!=" :
				type === "=" ?
				value === check :
				type === "*=" ?
				value.indexOf(check) >= 0 :
				type === "~=" ?
				(" " + value + " ").indexOf(check) >= 0 :
				!check ?
				value && result !== false :
				type === "!=" ?
				value != check :
				type === "^=" ?
				value.indexOf(check) === 0 :
				type === "$=" ?
				value.substr(value.length - check.length) === check :
				type === "|=" ?
				value === check || value.substr(0, check.length + 1) === check + "-" :
				false;
		},
		POS: function(elem, match, i, array){
			var name = match[2], filter = Expr.setFilters[ name ];

			if ( filter ) {
				return filter( elem, i, match, array );
			}
		}
	}
};

var origPOS = Expr.match.POS;

for ( var type in Expr.match ) {
	Expr.match[ type ] = new RegExp( Expr.match[ type ].source + /(?![^\[]*\])(?![^\(]*\))/.source );
	Expr.leftMatch[ type ] = new RegExp( /(^(?:.|\r|\n)*?)/.source + Expr.match[ type ].source );
}

var makeArray = function(array, results) {
	array = Array.prototype.slice.call( array, 0 );

	if ( results ) {
		results.push.apply( results, array );
		return results;
	}

	return array;
};

try {
	Array.prototype.slice.call( document.documentElement.childNodes, 0 );

} catch(e){
	makeArray = function(array, results) {
		var ret = results || [];

		if ( toString.call(array) === "[object Array]" ) {
			Array.prototype.push.apply( ret, array );
		} else {
			if ( typeof array.length === "number" ) {
				for ( var i = 0, l = array.length; i < l; i++ ) {
					ret.push( array[i] );
				}
			} else {
				for ( var i = 0; array[i]; i++ ) {
					ret.push( array[i] );
				}
			}
		}

		return ret;
	};
}

var sortOrder;

if ( document.documentElement.compareDocumentPosition ) {
	sortOrder = function( a, b ) {
		if ( !a.compareDocumentPosition || !b.compareDocumentPosition ) {
			if ( a == b ) {
				hasDuplicate = true;
			}
			return 0;
		}

		var ret = a.compareDocumentPosition(b) & 4 ? -1 : a === b ? 0 : 1;
		if ( ret === 0 ) {
			hasDuplicate = true;
		}
		return ret;
	};
} else if ( "sourceIndex" in document.documentElement ) {
	sortOrder = function( a, b ) {
		if ( !a.sourceIndex || !b.sourceIndex ) {
			if ( a == b ) {
				hasDuplicate = true;
			}
			return 0;
		}

		var ret = a.sourceIndex - b.sourceIndex;
		if ( ret === 0 ) {
			hasDuplicate = true;
		}
		return ret;
	};
} else if ( document.createRange ) {
	sortOrder = function( a, b ) {
		if ( !a.ownerDocument || !b.ownerDocument ) {
			if ( a == b ) {
				hasDuplicate = true;
			}
			return 0;
		}

		var aRange = a.ownerDocument.createRange(), bRange = b.ownerDocument.createRange();
		aRange.setStart(a, 0);
		aRange.setEnd(a, 0);
		bRange.setStart(b, 0);
		bRange.setEnd(b, 0);
		var ret = aRange.compareBoundaryPoints(Range.START_TO_END, bRange);
		if ( ret === 0 ) {
			hasDuplicate = true;
		}
		return ret;
	};
}

(function(){
	var form = document.createElement("div"),
		id = "script" + (new Date).getTime();
	form.innerHTML = "<a name='" + id + "'/>";

	var root = document.documentElement;
	root.insertBefore( form, root.firstChild );

	if ( !!document.getElementById( id ) ) {
		Expr.find.ID = function(match, context, isXML){
			if ( typeof context.getElementById !== "undefined" && !isXML ) {
				var m = context.getElementById(match[1]);
				return m ? m.id === match[1] || typeof m.getAttributeNode !== "undefined" && m.getAttributeNode("id").nodeValue === match[1] ? [m] : undefined : [];
			}
		};

		Expr.filter.ID = function(elem, match){
			var node = typeof elem.getAttributeNode !== "undefined" && elem.getAttributeNode("id");
			return elem.nodeType === 1 && node && node.nodeValue === match;
		};
	}

	root.removeChild( form );
	root = form = null; // release memory in IE
})();

(function(){

	var div = document.createElement("div");
	div.appendChild( document.createComment("") );

	if ( div.getElementsByTagName("*").length > 0 ) {
		Expr.find.TAG = function(match, context){
			var results = context.getElementsByTagName(match[1]);

			if ( match[1] === "*" ) {
				var tmp = [];

				for ( var i = 0; results[i]; i++ ) {
					if ( results[i].nodeType === 1 ) {
						tmp.push( results[i] );
					}
				}

				results = tmp;
			}

			return results;
		};
	}

	div.innerHTML = "<a href='#'></a>";
	if ( div.firstChild && typeof div.firstChild.getAttribute !== "undefined" &&
			div.firstChild.getAttribute("href") !== "#" ) {
		Expr.attrHandle.href = function(elem){
			return elem.getAttribute("href", 2);
		};
	}

	div = null; // release memory in IE
})();

if ( document.querySelectorAll ) (function(){
	var oldSizzle = Sizzle, div = document.createElement("div");
	div.innerHTML = "<p class='TEST'></p>";

	if ( div.querySelectorAll && div.querySelectorAll(".TEST").length === 0 ) {
		return;
	}

	Sizzle = function(query, context, extra, seed){
		context = context || document;

		if ( !seed && context.nodeType === 9 && !isXML(context) ) {
			try {
				return makeArray( context.querySelectorAll(query), extra );
			} catch(e){}
		}

		return oldSizzle(query, context, extra, seed);
	};

	for ( var prop in oldSizzle ) {
		Sizzle[ prop ] = oldSizzle[ prop ];
	}

	div = null; // release memory in IE
})();

if ( document.getElementsByClassName && document.documentElement.getElementsByClassName ) (function(){
	var div = document.createElement("div");
	div.innerHTML = "<div class='test e'></div><div class='test'></div>";

	if ( div.getElementsByClassName("e").length === 0 )
		return;

	div.lastChild.className = "e";

	if ( div.getElementsByClassName("e").length === 1 )
		return;

	Expr.order.splice(1, 0, "CLASS");
	Expr.find.CLASS = function(match, context, isXML) {
		if ( typeof context.getElementsByClassName !== "undefined" && !isXML ) {
			return context.getElementsByClassName(match[1]);
		}
	};

	div = null; // release memory in IE
})();

function dirNodeCheck( dir, cur, doneName, checkSet, nodeCheck, isXML ) {
	var sibDir = dir == "previousSibling" && !isXML;
	for ( var i = 0, l = checkSet.length; i < l; i++ ) {
		var elem = checkSet[i];
		if ( elem ) {
			if ( sibDir && elem.nodeType === 1 ){
				elem.sizcache = doneName;
				elem.sizset = i;
			}
			elem = elem[dir];
			var match = false;

			while ( elem ) {
				if ( elem.sizcache === doneName ) {
					match = checkSet[elem.sizset];
					break;
				}

				if ( elem.nodeType === 1 && !isXML ){
					elem.sizcache = doneName;
					elem.sizset = i;
				}

				if ( elem.nodeName === cur ) {
					match = elem;
					break;
				}

				elem = elem[dir];
			}

			checkSet[i] = match;
		}
	}
}

function dirCheck( dir, cur, doneName, checkSet, nodeCheck, isXML ) {
	var sibDir = dir == "previousSibling" && !isXML;
	for ( var i = 0, l = checkSet.length; i < l; i++ ) {
		var elem = checkSet[i];
		if ( elem ) {
			if ( sibDir && elem.nodeType === 1 ) {
				elem.sizcache = doneName;
				elem.sizset = i;
			}
			elem = elem[dir];
			var match = false;

			while ( elem ) {
				if ( elem.sizcache === doneName ) {
					match = checkSet[elem.sizset];
					break;
				}

				if ( elem.nodeType === 1 ) {
					if ( !isXML ) {
						elem.sizcache = doneName;
						elem.sizset = i;
					}
					if ( typeof cur !== "string" ) {
						if ( elem === cur ) {
							match = true;
							break;
						}

					} else if ( Sizzle.filter( cur, [elem] ).length > 0 ) {
						match = elem;
						break;
					}
				}

				elem = elem[dir];
			}

			checkSet[i] = match;
		}
	}
}

var contains = document.compareDocumentPosition ?  function(a, b){
	return a.compareDocumentPosition(b) & 16;
} : function(a, b){
	return a !== b && (a.contains ? a.contains(b) : true);
};

var isXML = function(elem){
	return elem.nodeType === 9 && elem.documentElement.nodeName !== "HTML" ||
		!!elem.ownerDocument && elem.ownerDocument.documentElement.nodeName !== "HTML";
};

var posProcess = function(selector, context){
	var tmpSet = [], later = "", match,
		root = context.nodeType ? [context] : context;

	while ( (match = Expr.match.PSEUDO.exec( selector )) ) {
		later += match[0];
		selector = selector.replace( Expr.match.PSEUDO, "" );
	}

	selector = Expr.relative[selector] ? selector + "*" : selector;

	for ( var i = 0, l = root.length; i < l; i++ ) {
		Sizzle( selector, root[i], tmpSet );
	}

	return Sizzle.filter( later, tmpSet );
};


window.Sizzle = Sizzle;

})();

;(function(engine) {
  var extendElements = Prototype.Selector.extendElements;

  function select(selector, scope) {
    return extendElements(engine(selector, scope || document));
  }

  function match(element, selector) {
    return engine.matches(selector, [element]).length == 1;
  }

  Prototype.Selector.engine = engine;
  Prototype.Selector.select = select;
  Prototype.Selector.match = match;
})(Sizzle);

window.Sizzle = Prototype._original_property;
delete Prototype._original_property;

var Form = {
  reset: function(form) {
    form = $(form);
    form.reset();
    return form;
  },

  serializeElements: function(elements, options) {
    if (typeof options != 'object') options = { hash: !!options };
    else if (Object.isUndefined(options.hash)) options.hash = true;
    var key, value, submitted = false, submit = options.submit, accumulator, initial;

    if (options.hash) {
      initial = {};
      accumulator = function(result, key, value) {
        if (key in result) {
          if (!Object.isArray(result[key])) result[key] = [result[key]];
          result[key].push(value);
        } else result[key] = value;
        return result;
      };
    } else {
      initial = '';
      accumulator = function(result, key, value) {
        return result + (result ? '&' : '') + encodeURIComponent(key) + '=' + encodeURIComponent(value);
      }
    }

    return elements.inject(initial, function(result, element) {
      if (!element.disabled && element.name) {
        key = element.name; value = $(element).getValue();
        if (value != null && element.type != 'file' && (element.type != 'submit' || (!submitted &&
            submit !== false && (!submit || key == submit) && (submitted = true)))) {
          result = accumulator(result, key, value);
        }
      }
      return result;
    });
  }
};

Form.Methods = {
  serialize: function(form, options) {
    return Form.serializeElements(Form.getElements(form), options);
  },

  getElements: function(form) {
    var elements = $(form).getElementsByTagName('*'),
        element,
        arr = [ ],
        serializers = Form.Element.Serializers;
    for (var i = 0; element = elements[i]; i++) {
      arr.push(element);
    }
    return arr.inject([], function(elements, child) {
      if (serializers[child.tagName.toLowerCase()])
        elements.push(Element.extend(child));
      return elements;
    })
  },

  getInputs: function(form, typeName, name) {
    form = $(form);
    var inputs = form.getElementsByTagName('input');

    if (!typeName && !name) return $A(inputs).map(Element.extend);

    for (var i = 0, matchingInputs = [], length = inputs.length; i < length; i++) {
      var input = inputs[i];
      if ((typeName && input.type != typeName) || (name && input.name != name))
        continue;
      matchingInputs.push(Element.extend(input));
    }

    return matchingInputs;
  },

  disable: function(form) {
    form = $(form);
    Form.getElements(form).invoke('disable');
    return form;
  },

  enable: function(form) {
    form = $(form);
    Form.getElements(form).invoke('enable');
    return form;
  },

  findFirstElement: function(form) {
    var elements = $(form).getElements().findAll(function(element) {
      return 'hidden' != element.type && !element.disabled;
    });
    var firstByIndex = elements.findAll(function(element) {
      return element.hasAttribute('tabIndex') && element.tabIndex >= 0;
    }).sortBy(function(element) { return element.tabIndex }).first();

    return firstByIndex ? firstByIndex : elements.find(function(element) {
      return /^(?:input|select|textarea)$/i.test(element.tagName);
    });
  },

  focusFirstElement: function(form) {
    form = $(form);
    var element = form.findFirstElement();
    if (element) element.activate();
    return form;
  },

  request: function(form, options) {
    form = $(form), options = Object.clone(options || { });

    var params = options.parameters, action = form.readAttribute('action') || '';
    if (action.blank()) action = window.location.href;
    options.parameters = form.serialize(true);

    if (params) {
      if (Object.isString(params)) params = params.toQueryParams();
      Object.extend(options.parameters, params);
    }

    if (form.hasAttribute('method') && !options.method)
      options.method = form.method;

    return new Ajax.Request(action, options);
  }
};

/*--------------------------------------------------------------------------*/


Form.Element = {
  focus: function(element) {
    $(element).focus();
    return element;
  },

  select: function(element) {
    $(element).select();
    return element;
  }
};

Form.Element.Methods = {

  serialize: function(element) {
    element = $(element);
    if (!element.disabled && element.name) {
      var value = element.getValue();
      if (value != undefined) {
        var pair = { };
        pair[element.name] = value;
        return Object.toQueryString(pair);
      }
    }
    return '';
  },

  getValue: function(element) {
    element = $(element);
    var method = element.tagName.toLowerCase();
    return Form.Element.Serializers[method](element);
  },

  setValue: function(element, value) {
    element = $(element);
    var method = element.tagName.toLowerCase();
    Form.Element.Serializers[method](element, value);
    return element;
  },

  clear: function(element) {
    $(element).value = '';
    return element;
  },

  present: function(element) {
    return $(element).value != '';
  },

  activate: function(element) {
    element = $(element);
    try {
      element.focus();
      if (element.select && (element.tagName.toLowerCase() != 'input' ||
          !(/^(?:button|reset|submit)$/i.test(element.type))))
        element.select();
    } catch (e) { }
    return element;
  },

  disable: function(element) {
    element = $(element);
    element.disabled = true;
    return element;
  },

  enable: function(element) {
    element = $(element);
    element.disabled = false;
    return element;
  }
};

/*--------------------------------------------------------------------------*/

var Field = Form.Element;

var $F = Form.Element.Methods.getValue;

/*--------------------------------------------------------------------------*/

Form.Element.Serializers = (function() {
  function input(element, value) {
    switch (element.type.toLowerCase()) {
      case 'checkbox':
      case 'radio':
        return inputSelector(element, value);
      default:
        return valueSelector(element, value);
    }
  }

  function inputSelector(element, value) {
    if (Object.isUndefined(value))
      return element.checked ? element.value : null;
    else element.checked = !!value;
  }

  function valueSelector(element, value) {
    if (Object.isUndefined(value)) return element.value;
    else element.value = value;
  }

  function select(element, value) {
    if (Object.isUndefined(value))
      return (element.type === 'select-one' ? selectOne : selectMany)(element);

    var opt, currentValue, single = !Object.isArray(value);
    for (var i = 0, length = element.length; i < length; i++) {
      opt = element.options[i];
      currentValue = this.optionValue(opt);
      if (single) {
        if (currentValue == value) {
          opt.selected = true;
          return;
        }
      }
      else opt.selected = value.include(currentValue);
    }
  }

  function selectOne(element) {
    var index = element.selectedIndex;
    return index >= 0 ? optionValue(element.options[index]) : null;
  }

  function selectMany(element) {
    var values, length = element.length;
    if (!length) return null;

    for (var i = 0, values = []; i < length; i++) {
      var opt = element.options[i];
      if (opt.selected) values.push(optionValue(opt));
    }
    return values;
  }

  function optionValue(opt) {
    return Element.hasAttribute(opt, 'value') ? opt.value : opt.text;
  }

  return {
    input:         input,
    inputSelector: inputSelector,
    textarea:      valueSelector,
    select:        select,
    selectOne:     selectOne,
    selectMany:    selectMany,
    optionValue:   optionValue,
    button:        valueSelector
  };
})();

/*--------------------------------------------------------------------------*/


Abstract.TimedObserver = Class.create(PeriodicalExecuter, {
  initialize: function($super, element, frequency, callback) {
    $super(callback, frequency);
    this.element   = $(element);
    this.lastValue = this.getValue();
  },

  execute: function() {
    var value = this.getValue();
    if (Object.isString(this.lastValue) && Object.isString(value) ?
        this.lastValue != value : String(this.lastValue) != String(value)) {
      this.callback(this.element, value);
      this.lastValue = value;
    }
  }
});

Form.Element.Observer = Class.create(Abstract.TimedObserver, {
  getValue: function() {
    return Form.Element.getValue(this.element);
  }
});

Form.Observer = Class.create(Abstract.TimedObserver, {
  getValue: function() {
    return Form.serialize(this.element);
  }
});

/*--------------------------------------------------------------------------*/

Abstract.EventObserver = Class.create({
  initialize: function(element, callback) {
    this.element  = $(element);
    this.callback = callback;

    this.lastValue = this.getValue();
    if (this.element.tagName.toLowerCase() == 'form')
      this.registerFormCallbacks();
    else
      this.registerCallback(this.element);
  },

  onElementEvent: function() {
    var value = this.getValue();
    if (this.lastValue != value) {
      this.callback(this.element, value);
      this.lastValue = value;
    }
  },

  registerFormCallbacks: function() {
    Form.getElements(this.element).each(this.registerCallback, this);
  },

  registerCallback: function(element) {
    if (element.type) {
      switch (element.type.toLowerCase()) {
        case 'checkbox':
        case 'radio':
          Event.observe(element, 'click', this.onElementEvent.bind(this));
          break;
        default:
          Event.observe(element, 'change', this.onElementEvent.bind(this));
          break;
      }
    }
  }
});

Form.Element.EventObserver = Class.create(Abstract.EventObserver, {
  getValue: function() {
    return Form.Element.getValue(this.element);
  }
});

Form.EventObserver = Class.create(Abstract.EventObserver, {
  getValue: function() {
    return Form.serialize(this.element);
  }
});
(function() {

  var Event = {
    KEY_BACKSPACE: 8,
    KEY_TAB:       9,
    KEY_RETURN:   13,
    KEY_ESC:      27,
    KEY_LEFT:     37,
    KEY_UP:       38,
    KEY_RIGHT:    39,
    KEY_DOWN:     40,
    KEY_DELETE:   46,
    KEY_HOME:     36,
    KEY_END:      35,
    KEY_PAGEUP:   33,
    KEY_PAGEDOWN: 34,
    KEY_INSERT:   45,

    cache: {}
  };

  var docEl = document.documentElement;
  var MOUSEENTER_MOUSELEAVE_EVENTS_SUPPORTED = 'onmouseenter' in docEl
    && 'onmouseleave' in docEl;



  var isIELegacyEvent = function(event) { return false; };

  if (window.attachEvent) {
    if (window.addEventListener) {
      isIELegacyEvent = function(event) {
        return !(event instanceof window.Event);
      };
    } else {
      isIELegacyEvent = function(event) { return true; };
    }
  }

  var _isButton;

  function _isButtonForDOMEvents(event, code) {
    return event.which ? (event.which === code + 1) : (event.button === code);
  }

  var legacyButtonMap = { 0: 1, 1: 4, 2: 2 };
  function _isButtonForLegacyEvents(event, code) {
    return event.button === legacyButtonMap[code];
  }

  function _isButtonForWebKit(event, code) {
    switch (code) {
      case 0: return event.which == 1 && !event.metaKey;
      case 1: return event.which == 2 || (event.which == 1 && event.metaKey);
      case 2: return event.which == 3;
      default: return false;
    }
  }

  if (window.attachEvent) {
    if (!window.addEventListener) {
      _isButton = _isButtonForLegacyEvents;
    } else {
      _isButton = function(event, code) {
        return isIELegacyEvent(event) ? _isButtonForLegacyEvents(event, code) :
         _isButtonForDOMEvents(event, code);
      }
    }
  } else if (Prototype.Browser.WebKit) {
    _isButton = _isButtonForWebKit;
  } else {
    _isButton = _isButtonForDOMEvents;
  }

  function isLeftClick(event)   { return _isButton(event, 0) }

  function isMiddleClick(event) { return _isButton(event, 1) }

  function isRightClick(event)  { return _isButton(event, 2) }

  function element(event) {
    event = Event.extend(event);

    var node = event.target, type = event.type,
     currentTarget = event.currentTarget;

    if (currentTarget && currentTarget.tagName) {
      if (type === 'load' || type === 'error' ||
        (type === 'click' && currentTarget.tagName.toLowerCase() === 'input'
          && currentTarget.type === 'radio'))
            node = currentTarget;
    }

    if (node.nodeType == Node.TEXT_NODE)
      node = node.parentNode;

    return Element.extend(node);
  }

  function findElement(event, expression) {
    var element = Event.element(event);

    if (!expression) return element;
    while (element) {
      if (Object.isElement(element) && Prototype.Selector.match(element, expression)) {
        return Element.extend(element);
      }
      element = element.parentNode;
    }
  }

  function pointer(event) {
    return { x: pointerX(event), y: pointerY(event) };
  }

  function pointerX(event) {
    var docElement = document.documentElement,
     body = document.body || { scrollLeft: 0 };

    return event.pageX || (event.clientX +
      (docElement.scrollLeft || body.scrollLeft) -
      (docElement.clientLeft || 0));
  }

  function pointerY(event) {
    var docElement = document.documentElement,
     body = document.body || { scrollTop: 0 };

    return  event.pageY || (event.clientY +
       (docElement.scrollTop || body.scrollTop) -
       (docElement.clientTop || 0));
  }


  function stop(event) {
    Event.extend(event);
    event.preventDefault();
    event.stopPropagation();

    event.stopped = true;
  }


  Event.Methods = {
    isLeftClick:   isLeftClick,
    isMiddleClick: isMiddleClick,
    isRightClick:  isRightClick,

    element:     element,
    findElement: findElement,

    pointer:  pointer,
    pointerX: pointerX,
    pointerY: pointerY,

    stop: stop
  };

  var methods = Object.keys(Event.Methods).inject({ }, function(m, name) {
    m[name] = Event.Methods[name].methodize();
    return m;
  });

  if (window.attachEvent) {
    function _relatedTarget(event) {
      var element;
      switch (event.type) {
        case 'mouseover':
        case 'mouseenter':
          element = event.fromElement;
          break;
        case 'mouseout':
        case 'mouseleave':
          element = event.toElement;
          break;
        default:
          return null;
      }
      return Element.extend(element);
    }

    var additionalMethods = {
      stopPropagation: function() { this.cancelBubble = true },
      preventDefault:  function() { this.returnValue = false },
      inspect: function() { return '[object Event]' }
    };

    Event.extend = function(event, element) {
      if (!event) return false;

      if (!isIELegacyEvent(event)) return event;

      if (event._extendedByPrototype) return event;
      event._extendedByPrototype = Prototype.emptyFunction;

      var pointer = Event.pointer(event);

      Object.extend(event, {
        target: event.srcElement || element,
        relatedTarget: _relatedTarget(event),
        pageX:  pointer.x,
        pageY:  pointer.y
      });

      Object.extend(event, methods);
      Object.extend(event, additionalMethods);

      return event;
    };
  } else {
    Event.extend = Prototype.K;
  }

  if (window.addEventListener) {
    Event.prototype = window.Event.prototype || document.createEvent('HTMLEvents').__proto__;
    Object.extend(Event.prototype, methods);
  }

  function _createResponder(element, eventName, handler) {
    var registry = Element.retrieve(element, 'prototype_event_registry');

    if (Object.isUndefined(registry)) {
      CACHE.push(element);
      registry = Element.retrieve(element, 'prototype_event_registry', $H());
    }

    var respondersForEvent = registry.get(eventName);
    if (Object.isUndefined(respondersForEvent)) {
      respondersForEvent = [];
      registry.set(eventName, respondersForEvent);
    }

    if (respondersForEvent.pluck('handler').include(handler)) return false;

    var responder;
    if (eventName.include(":")) {
      responder = function(event) {
        if (Object.isUndefined(event.eventName))
          return false;

        if (event.eventName !== eventName)
          return false;

        Event.extend(event, element);
        handler.call(element, event);
      };
    } else {
      if (!MOUSEENTER_MOUSELEAVE_EVENTS_SUPPORTED &&
       (eventName === "mouseenter" || eventName === "mouseleave")) {
        if (eventName === "mouseenter" || eventName === "mouseleave") {
          responder = function(event) {
            Event.extend(event, element);

            var parent = event.relatedTarget;
            while (parent && parent !== element) {
              try { parent = parent.parentNode; }
              catch(e) { parent = element; }
            }

            if (parent === element) return;

            handler.call(element, event);
          };
        }
      } else {
        responder = function(event) {
          Event.extend(event, element);
          handler.call(element, event);
        };
      }
    }

    responder.handler = handler;
    respondersForEvent.push(responder);
    return responder;
  }

  function _destroyCache() {
    for (var i = 0, length = CACHE.length; i < length; i++) {
      Event.stopObserving(CACHE[i]);
      CACHE[i] = null;
    }
  }

  var CACHE = [];

  if (Prototype.Browser.IE)
    window.attachEvent('onunload', _destroyCache);

  if (Prototype.Browser.WebKit)
    window.addEventListener('unload', Prototype.emptyFunction, false);


  var _getDOMEventName = Prototype.K,
      translations = { mouseenter: "mouseover", mouseleave: "mouseout" };

  if (!MOUSEENTER_MOUSELEAVE_EVENTS_SUPPORTED) {
    _getDOMEventName = function(eventName) {
      return (translations[eventName] || eventName);
    };
  }

  function observe(element, eventName, handler) {
    element = $(element);

    var responder = _createResponder(element, eventName, handler);

    if (!responder) return element;

    if (eventName.include(':')) {
      if (element.addEventListener)
        element.addEventListener("dataavailable", responder, false);
      else {
        element.attachEvent("ondataavailable", responder);
        element.attachEvent("onlosecapture", responder);
      }
    } else {
      var actualEventName = _getDOMEventName(eventName);

      if (element.addEventListener)
        element.addEventListener(actualEventName, responder, false);
      else
        element.attachEvent("on" + actualEventName, responder);
    }

    return element;
  }

  function stopObserving(element, eventName, handler) {
    element = $(element);

    var registry = Element.retrieve(element, 'prototype_event_registry');
    if (!registry) return element;

    if (!eventName) {
      registry.each( function(pair) {
        var eventName = pair.key;
        stopObserving(element, eventName);
      });
      return element;
    }

    var responders = registry.get(eventName);
    if (!responders) return element;

    if (!handler) {
      responders.each(function(r) {
        stopObserving(element, eventName, r.handler);
      });
      return element;
    }

    var i = responders.length, responder;
    while (i--) {
      if (responders[i].handler === handler) {
        responder = responders[i];
        break;
      }
    }
    if (!responder) return element;

    if (eventName.include(':')) {
      if (element.removeEventListener)
        element.removeEventListener("dataavailable", responder, false);
      else {
        element.detachEvent("ondataavailable", responder);
        element.detachEvent("onlosecapture", responder);
      }
    } else {
      var actualEventName = _getDOMEventName(eventName);
      if (element.removeEventListener)
        element.removeEventListener(actualEventName, responder, false);
      else
        element.detachEvent('on' + actualEventName, responder);
    }

    registry.set(eventName, responders.without(responder));

    return element;
  }

  function fire(element, eventName, memo, bubble) {
    element = $(element);

    if (Object.isUndefined(bubble))
      bubble = true;

    if (element == document && document.createEvent && !element.dispatchEvent)
      element = document.documentElement;

    var event;
    if (document.createEvent) {
      event = document.createEvent('HTMLEvents');
      event.initEvent('dataavailable', bubble, true);
    } else {
      event = document.createEventObject();
      event.eventType = bubble ? 'ondataavailable' : 'onlosecapture';
    }

    event.eventName = eventName;
    event.memo = memo || { };

    if (document.createEvent)
      element.dispatchEvent(event);
    else
      element.fireEvent(event.eventType, event);

    return Event.extend(event);
  }

  Event.Handler = Class.create({
    initialize: function(element, eventName, selector, callback) {
      this.element   = $(element);
      this.eventName = eventName;
      this.selector  = selector;
      this.callback  = callback;
      this.handler   = this.handleEvent.bind(this);
    },

    start: function() {
      Event.observe(this.element, this.eventName, this.handler);
      return this;
    },

    stop: function() {
      Event.stopObserving(this.element, this.eventName, this.handler);
      return this;
    },

    handleEvent: function(event) {
      var element = Event.findElement(event, this.selector);
      if (element) this.callback.call(this.element, event, element);
    }
  });

  function on(element, eventName, selector, callback) {
    element = $(element);
    if (Object.isFunction(selector) && Object.isUndefined(callback)) {
      callback = selector, selector = null;
    }

    return new Event.Handler(element, eventName, selector, callback).start();
  }

  Object.extend(Event, Event.Methods);

  Object.extend(Event, {
    fire:          fire,
    observe:       observe,
    stopObserving: stopObserving,
    on:            on
  });

  Element.addMethods({
    fire:          fire,

    observe:       observe,

    stopObserving: stopObserving,

    on:            on
  });

  Object.extend(document, {
    fire:          fire.methodize(),

    observe:       observe.methodize(),

    stopObserving: stopObserving.methodize(),

    on:            on.methodize(),

    loaded:        false
  });

  if (window.Event) Object.extend(window.Event, Event);
  else window.Event = Event;
})();

(function() {
  /* Support for the DOMContentLoaded event is based on work by Dan Webb,
     Matthias Miller, Dean Edwards, John Resig, and Diego Perini. */

  var timer;

  function fireContentLoadedEvent() {
    if (document.loaded) return;
    if (timer) window.clearTimeout(timer);
    document.loaded = true;
    document.fire('dom:loaded');
  }

  function checkReadyState() {
    if (document.readyState === 'complete') {
      document.stopObserving('readystatechange', checkReadyState);
      fireContentLoadedEvent();
    }
  }

  function pollDoScroll() {
    try { document.documentElement.doScroll('left'); }
    catch(e) {
      timer = pollDoScroll.defer();
      return;
    }
    fireContentLoadedEvent();
  }

  if (document.addEventListener) {
    document.addEventListener('DOMContentLoaded', fireContentLoadedEvent, false);
  } else {
    document.observe('readystatechange', checkReadyState);
    if (window == top)
      timer = pollDoScroll.defer();
  }

  Event.observe(window, 'load', fireContentLoadedEvent);
})();

Element.addMethods();

/*------------------------------- DEPRECATED -------------------------------*/

Hash.toQueryString = Object.toQueryString;

var Toggle = { display: Element.toggle };

Element.Methods.childOf = Element.Methods.descendantOf;

var Insertion = {
  Before: function(element, content) {
    return Element.insert(element, {before:content});
  },

  Top: function(element, content) {
    return Element.insert(element, {top:content});
  },

  Bottom: function(element, content) {
    return Element.insert(element, {bottom:content});
  },

  After: function(element, content) {
    return Element.insert(element, {after:content});
  }
};

var $continue = new Error('"throw $continue" is deprecated, use "return" instead');

var Position = {
  includeScrollOffsets: false,

  prepare: function() {
    this.deltaX =  window.pageXOffset
                || document.documentElement.scrollLeft
                || document.body.scrollLeft
                || 0;
    this.deltaY =  window.pageYOffset
                || document.documentElement.scrollTop
                || document.body.scrollTop
                || 0;
  },

  within: function(element, x, y) {
    if (this.includeScrollOffsets)
      return this.withinIncludingScrolloffsets(element, x, y);
    this.xcomp = x;
    this.ycomp = y;
    this.offset = Element.cumulativeOffset(element);

    return (y >= this.offset[1] &&
            y <  this.offset[1] + element.offsetHeight &&
            x >= this.offset[0] &&
            x <  this.offset[0] + element.offsetWidth);
  },

  withinIncludingScrolloffsets: function(element, x, y) {
    var offsetcache = Element.cumulativeScrollOffset(element);

    this.xcomp = x + offsetcache[0] - this.deltaX;
    this.ycomp = y + offsetcache[1] - this.deltaY;
    this.offset = Element.cumulativeOffset(element);

    return (this.ycomp >= this.offset[1] &&
            this.ycomp <  this.offset[1] + element.offsetHeight &&
            this.xcomp >= this.offset[0] &&
            this.xcomp <  this.offset[0] + element.offsetWidth);
  },

  overlap: function(mode, element) {
    if (!mode) return 0;
    if (mode == 'vertical')
      return ((this.offset[1] + element.offsetHeight) - this.ycomp) /
        element.offsetHeight;
    if (mode == 'horizontal')
      return ((this.offset[0] + element.offsetWidth) - this.xcomp) /
        element.offsetWidth;
  },


  cumulativeOffset: Element.Methods.cumulativeOffset,

  positionedOffset: Element.Methods.positionedOffset,

  absolutize: function(element) {
    Position.prepare();
    return Element.absolutize(element);
  },

  relativize: function(element) {
    Position.prepare();
    return Element.relativize(element);
  },

  realOffset: Element.Methods.cumulativeScrollOffset,

  offsetParent: Element.Methods.getOffsetParent,

  page: Element.Methods.viewportOffset,

  clone: function(source, target, options) {
    options = options || { };
    return Element.clonePosition(target, source, options);
  }
};

/*--------------------------------------------------------------------------*/

if (!document.getElementsByClassName) document.getElementsByClassName = function(instanceMethods){
  function iter(name) {
    return name.blank() ? null : "[contains(concat(' ', @class, ' '), ' " + name + " ')]";
  }

  instanceMethods.getElementsByClassName = Prototype.BrowserFeatures.XPath ?
  function(element, className) {
    className = className.toString().strip();
    var cond = /\s/.test(className) ? $w(className).map(iter).join('') : iter(className);
    return cond ? document._getElementsByXPath('.//*' + cond, element) : [];
  } : function(element, className) {
    className = className.toString().strip();
    var elements = [], classNames = (/\s/.test(className) ? $w(className) : null);
    if (!classNames && !className) return elements;

    var nodes = $(element).getElementsByTagName('*');
    className = ' ' + className + ' ';

    for (var i = 0, child, cn; child = nodes[i]; i++) {
      if (child.className && (cn = ' ' + child.className + ' ') && (cn.include(className) ||
          (classNames && classNames.all(function(name) {
            return !name.toString().blank() && cn.include(' ' + name + ' ');
          }))))
        elements.push(Element.extend(child));
    }
    return elements;
  };

  return function(className, parentElement) {
    return $(parentElement || document.body).getElementsByClassName(className);
  };
}(Element.Methods);

/*--------------------------------------------------------------------------*/

Element.ClassNames = Class.create();
Element.ClassNames.prototype = {
  initialize: function(element) {
    this.element = $(element);
  },

  _each: function(iterator) {
    this.element.className.split(/\s+/).select(function(name) {
      return name.length > 0;
    })._each(iterator);
  },

  set: function(className) {
    this.element.className = className;
  },

  add: function(classNameToAdd) {
    if (this.include(classNameToAdd)) return;
    this.set($A(this).concat(classNameToAdd).join(' '));
  },

  remove: function(classNameToRemove) {
    if (!this.include(classNameToRemove)) return;
    this.set($A(this).without(classNameToRemove).join(' '));
  },

  toString: function() {
    return $A(this).join(' ');
  }
};

Object.extend(Element.ClassNames.prototype, Enumerable);

/*--------------------------------------------------------------------------*/

(function() {
  window.Selector = Class.create({
    initialize: function(expression) {
      this.expression = expression.strip();
    },

    findElements: function(rootElement) {
      return Prototype.Selector.select(this.expression, rootElement);
    },

    match: function(element) {
      return Prototype.Selector.match(element, this.expression);
    },

    toString: function() {
      return this.expression;
    },

    inspect: function() {
      return "#<Selector: " + this.expression + ">";
    }
  });

  Object.extend(Selector, {
    matchElements: function(elements, expression) {
      var match = Prototype.Selector.match,
          results = [];

      for (var i = 0, length = elements.length; i < length; i++) {
        var element = elements[i];
        if (match(element, expression)) {
          results.push(Element.extend(element));
        }
      }
      return results;
    },

    findElement: function(elements, expression, index) {
      index = index || 0;
      var matchIndex = 0, element;
      for (var i = 0, length = elements.length; i < length; i++) {
        element = elements[i];
        if (Prototype.Selector.match(element, expression) && index === matchIndex++) {
          return Element.extend(element);
        }
      }
    },

    findChildElements: function(element, expressions) {
      var selector = expressions.toArray().join(', ');
      return Prototype.Selector.select(selector, element || document);
    }
  });
})();


// Copyright (c) 2005-2008 Thomas Fuchs (http://script.aculo.us, http://mir.aculo.us)
// Contributors:
//  Justin Palmer (http://encytemedia.com/)
//  Mark Pilgrim (http://diveintomark.org/)
//  Martin Bialasinki
// 
// script.aculo.us is freely distributable under the terms of an MIT-style license.
// For details, see the script.aculo.us web site: http://script.aculo.us/ 

// converts rgb() and #xxx to #xxxxxx format,  
// returns self (or first argument) if not convertable  
String.prototype.parseColor = function() {  
  var color = '#';
  if (this.slice(0,4) == 'rgb(') {  
    var cols = this.slice(4,this.length-1).split(',');  
    var i=0; do { color += parseInt(cols[i]).toColorPart() } while (++i<3);  
  } else {  
    if (this.slice(0,1) == '#') {  
      if (this.length==4) for(var i=1;i<4;i++) color += (this.charAt(i) + this.charAt(i)).toLowerCase();  
      if (this.length==7) color = this.toLowerCase();  
    }  
  }  
  return (color.length==7 ? color : (arguments[0] || this));  
};

/*--------------------------------------------------------------------------*/

Element.collectTextNodes = function(element) {  
  return $A($(element).childNodes).collect( function(node) {
    return (node.nodeType==3 ? node.nodeValue : 
      (node.hasChildNodes() ? Element.collectTextNodes(node) : ''));
  }).flatten().join('');
};

Element.collectTextNodesIgnoreClass = function(element, className) {  
  return $A($(element).childNodes).collect( function(node) {
    return (node.nodeType==3 ? node.nodeValue : 
      ((node.hasChildNodes() && !Element.hasClassName(node,className)) ? 
        Element.collectTextNodesIgnoreClass(node, className) : ''));
  }).flatten().join('');
};

Element.setContentZoom = function(element, percent) {
  element = $(element);  
  element.setStyle({fontSize: (percent/100) + 'em'});   
  if (Prototype.Browser.WebKit) window.scrollBy(0,0);
  return element;
};

Element.getInlineOpacity = function(element){
  return $(element).style.opacity || '';
};

Element.forceRerendering = function(element) {
  try {
    element = $(element);
    var n = document.createTextNode(' ');
    element.appendChild(n);
    element.removeChild(n);
  } catch(e) { }
};

/*--------------------------------------------------------------------------*/

var Effect = {
  _elementDoesNotExistError: {
    name: 'ElementDoesNotExistError',
    message: 'The specified DOM element does not exist, but is required for this effect to operate'
  },
  Transitions: {
    linear: Prototype.K,
    sinoidal: function(pos) {
      return (-Math.cos(pos*Math.PI)/2) + 0.5;
    },
    reverse: function(pos) {
      return 1-pos;
    },
    flicker: function(pos) {
      var pos = ((-Math.cos(pos*Math.PI)/4) + 0.75) + Math.random()/4;
      return pos > 1 ? 1 : pos;
    },
    wobble: function(pos) {
      return (-Math.cos(pos*Math.PI*(9*pos))/2) + 0.5;
    },
    pulse: function(pos, pulses) { 
      pulses = pulses || 5; 
      return (
        ((pos % (1/pulses)) * pulses).round() == 0 ? 
              ((pos * pulses * 2) - (pos * pulses * 2).floor()) : 
          1 - ((pos * pulses * 2) - (pos * pulses * 2).floor())
        );
    },
    spring: function(pos) { 
      return 1 - (Math.cos(pos * 4.5 * Math.PI) * Math.exp(-pos * 6)); 
    },
    none: function(pos) {
      return 0;
    },
    full: function(pos) {
      return 1;
    }
  },
  DefaultOptions: {
    duration:   1.0,   // seconds
    fps:        100,   // 100= assume 66fps max.
    sync:       false, // true for combining
    from:       0.0,
    to:         1.0,
    delay:      0.0,
    queue:      'parallel'
  },
  tagifyText: function(element) {
    var tagifyStyle = 'position:relative';
    if (Prototype.Browser.IE) tagifyStyle += ';zoom:1';
    
    element = $(element);
    $A(element.childNodes).each( function(child) {
      if (child.nodeType==3) {
        child.nodeValue.toArray().each( function(character) {
          element.insertBefore(
            new Element('span', {style: tagifyStyle}).update(
              character == ' ' ? String.fromCharCode(160) : character), 
              child);
        });
        Element.remove(child);
      }
    });
  },
  multiple: function(element, effect) {
    var elements;
    if (((typeof element == 'object') || 
        Object.isFunction(element)) && 
       (element.length))
      elements = element;
    else
      elements = $(element).childNodes;
      
    var options = Object.extend({
      speed: 0.1,
      delay: 0.0
    }, arguments[2] || { });
    var masterDelay = options.delay;

    $A(elements).each( function(element, index) {
      new effect(element, Object.extend(options, { delay: index * options.speed + masterDelay }));
    });
  },
  PAIRS: {
    'slide':  ['SlideDown','SlideUp'],
    'blind':  ['BlindDown','BlindUp'],
    'appear': ['Appear','Fade']
  },
  toggle: function(element, effect) {
    element = $(element);
    effect = (effect || 'appear').toLowerCase();
    var options = Object.extend({
      queue: { position:'end', scope:(element.id || 'global'), limit: 1 }
    }, arguments[2] || { });
    Effect[element.visible() ? 
      Effect.PAIRS[effect][1] : Effect.PAIRS[effect][0]](element, options);
  }
};

Effect.DefaultOptions.transition = Effect.Transitions.sinoidal;

/* ------------- core effects ------------- */

Effect.ScopedQueue = Class.create(Enumerable, {
  initialize: function() {
    this.effects  = [];
    this.interval = null;    
  },
  _each: function(iterator) {
    this.effects._each(iterator);
  },
  add: function(effect) {
    var timestamp = new Date().getTime();
    
    var position = Object.isString(effect.options.queue) ? 
      effect.options.queue : effect.options.queue.position;
    
    switch(position) {
      case 'front':
        // move unstarted effects after this effect  
        this.effects.findAll(function(e){ return e.state=='idle' }).each( function(e) {
            e.startOn  += effect.finishOn;
            e.finishOn += effect.finishOn;
          });
        break;
      case 'with-last':
        timestamp = this.effects.pluck('startOn').max() || timestamp;
        break;
      case 'end':
        // start effect after last queued effect has finished
        timestamp = this.effects.pluck('finishOn').max() || timestamp;
        break;
    }
    
    effect.startOn  += timestamp;
    effect.finishOn += timestamp;

    if (!effect.options.queue.limit || (this.effects.length < effect.options.queue.limit))
      this.effects.push(effect);
    
    if (!this.interval)
      this.interval = setInterval(this.loop.bind(this), 15);
  },
  remove: function(effect) {
    this.effects = this.effects.reject(function(e) { return e==effect });
    if (this.effects.length == 0) {
      clearInterval(this.interval);
      this.interval = null;
    }
  },
  loop: function() {
    var timePos = new Date().getTime();
    for(var i=0, len=this.effects.length;i<len;i++) 
      this.effects[i] && this.effects[i].loop(timePos);
  }
});

Effect.Queues = {
  instances: $H(),
  get: function(queueName) {
    if (!Object.isString(queueName)) return queueName;
    
    return this.instances.get(queueName) ||
      this.instances.set(queueName, new Effect.ScopedQueue());
  }
};
Effect.Queue = Effect.Queues.get('global');

Effect.Base = Class.create({
  position: null,
  start: function(options) {
    function codeForEvent(options,eventName){
      return (
        (options[eventName+'Internal'] ? 'this.options.'+eventName+'Internal(this);' : '') +
        (options[eventName] ? 'this.options.'+eventName+'(this);' : '')
      );
    }
    if (options && options.transition === false) options.transition = Effect.Transitions.linear;
    this.options      = Object.extend(Object.extend({ },Effect.DefaultOptions), options || { });
    this.currentFrame = 0;
    this.state        = 'idle';
    this.startOn      = this.options.delay*1000;
    this.finishOn     = this.startOn+(this.options.duration*1000);
    this.fromToDelta  = this.options.to-this.options.from;
    this.totalTime    = this.finishOn-this.startOn;
    this.totalFrames  = this.options.fps*this.options.duration;
    
    eval('this.render = function(pos){ '+
      'if (this.state=="idle"){this.state="running";'+
      codeForEvent(this.options,'beforeSetup')+
      (this.setup ? 'this.setup();':'')+ 
      codeForEvent(this.options,'afterSetup')+
      '};if (this.state=="running"){'+
      'pos=this.options.transition(pos)*'+this.fromToDelta+'+'+this.options.from+';'+
      'this.position=pos;'+
      codeForEvent(this.options,'beforeUpdate')+
      (this.update ? 'this.update(pos);':'')+
      codeForEvent(this.options,'afterUpdate')+
      '}}');
    
    this.event('beforeStart');
    if (!this.options.sync)
      Effect.Queues.get(Object.isString(this.options.queue) ? 
        'global' : this.options.queue.scope).add(this);
  },
  loop: function(timePos) {
    if (timePos >= this.startOn) {
      if (timePos >= this.finishOn) {
        this.render(1.0);
        this.cancel();
        this.event('beforeFinish');
        if (this.finish) this.finish(); 
        this.event('afterFinish');
        return;  
      }
      var pos   = (timePos - this.startOn) / this.totalTime,
          frame = (pos * this.totalFrames).round();
      if (frame > this.currentFrame) {
        this.render(pos);
        this.currentFrame = frame;
      }
    }
  },
  cancel: function() {
    if (!this.options.sync)
      Effect.Queues.get(Object.isString(this.options.queue) ? 
        'global' : this.options.queue.scope).remove(this);
    this.state = 'finished';
  },
  event: function(eventName) {
    if (this.options[eventName + 'Internal']) this.options[eventName + 'Internal'](this);
    if (this.options[eventName]) this.options[eventName](this);
  },
  inspect: function() {
    var data = $H();
    for(property in this)
      if (!Object.isFunction(this[property])) data.set(property, this[property]);
    return '#<Effect:' + data.inspect() + ',options:' + $H(this.options).inspect() + '>';
  }
});

Effect.Parallel = Class.create(Effect.Base, {
  initialize: function(effects) {
    this.effects = effects || [];
    this.start(arguments[1]);
  },
  update: function(position) {
    this.effects.invoke('render', position);
  },
  finish: function(position) {
    this.effects.each( function(effect) {
      effect.render(1.0);
      effect.cancel();
      effect.event('beforeFinish');
      if (effect.finish) effect.finish(position);
      effect.event('afterFinish');
    });
  }
});

Effect.Tween = Class.create(Effect.Base, {
  initialize: function(object, from, to) {
    object = Object.isString(object) ? $(object) : object;
    var args = $A(arguments), method = args.last(), 
      options = args.length == 5 ? args[3] : null;
    this.method = Object.isFunction(method) ? method.bind(object) :
      Object.isFunction(object[method]) ? object[method].bind(object) : 
      function(value) { object[method] = value };
    this.start(Object.extend({ from: from, to: to }, options || { }));
  },
  update: function(position) {
    this.method(position);
  }
});

Effect.Event = Class.create(Effect.Base, {
  initialize: function() {
    this.start(Object.extend({ duration: 0 }, arguments[0] || { }));
  },
  update: Prototype.emptyFunction
});

Effect.Opacity = Class.create(Effect.Base, {
  initialize: function(element) {
    this.element = $(element);
    if (!this.element) throw(Effect._elementDoesNotExistError);
    // make this work on IE on elements without 'layout'
    if (Prototype.Browser.IE && (!this.element.currentStyle.hasLayout))
      this.element.setStyle({zoom: 1});
    var options = Object.extend({
      from: this.element.getOpacity() || 0.0,
      to:   1.0
    }, arguments[1] || { });
    this.start(options);
  },
  update: function(position) {
    this.element.setOpacity(position);
  }
});

Effect.Move = Class.create(Effect.Base, {
  initialize: function(element) {
    this.element = $(element);
    if (!this.element) throw(Effect._elementDoesNotExistError);
    var options = Object.extend({
      x:    0,
      y:    0,
      mode: 'relative'
    }, arguments[1] || { });
    this.start(options);
  },
  setup: function() {
    this.element.makePositioned();
    this.originalLeft = parseFloat(this.element.getStyle('left') || '0');
    this.originalTop  = parseFloat(this.element.getStyle('top')  || '0');
    if (this.options.mode == 'absolute') {
      this.options.x = this.options.x - this.originalLeft;
      this.options.y = this.options.y - this.originalTop;
    }
  },
  update: function(position) {
    this.element.setStyle({
      left: (this.options.x  * position + this.originalLeft).round() + 'px',
      top:  (this.options.y  * position + this.originalTop).round()  + 'px'
    });
  }
});

// for backwards compatibility
Effect.MoveBy = function(element, toTop, toLeft) {
  return new Effect.Move(element, 
    Object.extend({ x: toLeft, y: toTop }, arguments[3] || { }));
};

Effect.Scale = Class.create(Effect.Base, {
  initialize: function(element, percent) {
    this.element = $(element);
    if (!this.element) throw(Effect._elementDoesNotExistError);
    var options = Object.extend({
      scaleX: true,
      scaleY: true,
      scaleContent: true,
      scaleFromCenter: false,
      scaleMode: 'box',        // 'box' or 'contents' or { } with provided values
      scaleFrom: 100.0,
      scaleTo:   percent
    }, arguments[2] || { });
    this.start(options);
  },
  setup: function() {
    this.restoreAfterFinish = this.options.restoreAfterFinish || false;
    this.elementPositioning = this.element.getStyle('position');
    
    this.originalStyle = { };
    ['top','left','width','height','fontSize'].each( function(k) {
      this.originalStyle[k] = this.element.style[k];
    }.bind(this));
      
    this.originalTop  = this.element.offsetTop;
    this.originalLeft = this.element.offsetLeft;
    
    var fontSize = this.element.getStyle('font-size') || '100%';
    ['em','px','%','pt'].each( function(fontSizeType) {
      if (fontSize.indexOf(fontSizeType)>0) {
        this.fontSize     = parseFloat(fontSize);
        this.fontSizeType = fontSizeType;
      }
    }.bind(this));
    
    this.factor = (this.options.scaleTo - this.options.scaleFrom)/100;
    
    this.dims = null;
    if (this.options.scaleMode=='box')
      this.dims = [this.element.offsetHeight, this.element.offsetWidth];
    if (/^content/.test(this.options.scaleMode))
      this.dims = [this.element.scrollHeight, this.element.scrollWidth];
    if (!this.dims)
      this.dims = [this.options.scaleMode.originalHeight,
                   this.options.scaleMode.originalWidth];
  },
  update: function(position) {
    var currentScale = (this.options.scaleFrom/100.0) + (this.factor * position);
    if (this.options.scaleContent && this.fontSize)
      this.element.setStyle({fontSize: this.fontSize * currentScale + this.fontSizeType });
    this.setDimensions(this.dims[0] * currentScale, this.dims[1] * currentScale);
  },
  finish: function(position) {
    if (this.restoreAfterFinish) this.element.setStyle(this.originalStyle);
  },
  setDimensions: function(height, width) {
    var d = { };
    if (this.options.scaleX) d.width = width.round() + 'px';
    if (this.options.scaleY) d.height = height.round() + 'px';
    if (this.options.scaleFromCenter) {
      var topd  = (height - this.dims[0])/2;
      var leftd = (width  - this.dims[1])/2;
      if (this.elementPositioning == 'absolute') {
        if (this.options.scaleY) d.top = this.originalTop-topd + 'px';
        if (this.options.scaleX) d.left = this.originalLeft-leftd + 'px';
      } else {
        if (this.options.scaleY) d.top = -topd + 'px';
        if (this.options.scaleX) d.left = -leftd + 'px';
      }
    }
    this.element.setStyle(d);
  }
});

Effect.Highlight = Class.create(Effect.Base, {
  initialize: function(element) {
    this.element = $(element);
    if (!this.element) throw(Effect._elementDoesNotExistError);
    var options = Object.extend({ startcolor: '#ffff99' }, arguments[1] || { });
    this.start(options);
  },
  setup: function() {
    // Prevent executing on elements not in the layout flow
    if (this.element.getStyle('display')=='none') { this.cancel(); return; }
    // Disable background image during the effect
    this.oldStyle = { };
    if (!this.options.keepBackgroundImage) {
      this.oldStyle.backgroundImage = this.element.getStyle('background-image');
      this.element.setStyle({backgroundImage: 'none'});
    }
    if (!this.options.endcolor)
      this.options.endcolor = this.element.getStyle('background-color').parseColor('#ffffff');
    if (!this.options.restorecolor)
      this.options.restorecolor = this.element.getStyle('background-color');
    // init color calculations
    this._base  = $R(0,2).map(function(i){ return parseInt(this.options.startcolor.slice(i*2+1,i*2+3),16) }.bind(this));
    this._delta = $R(0,2).map(function(i){ return parseInt(this.options.endcolor.slice(i*2+1,i*2+3),16)-this._base[i] }.bind(this));
  },
  update: function(position) {
    this.element.setStyle({backgroundColor: $R(0,2).inject('#',function(m,v,i){
      return m+((this._base[i]+(this._delta[i]*position)).round().toColorPart()); }.bind(this)) });
  },
  finish: function() {
    this.element.setStyle(Object.extend(this.oldStyle, {
      backgroundColor: this.options.restorecolor
    }));
  }
});

Effect.ScrollTo = function(element) {
  var options = arguments[1] || { },
    scrollOffsets = document.viewport.getScrollOffsets(),
    elementOffsets = $(element).cumulativeOffset(),
    max = (window.height || document.body.scrollHeight) - document.viewport.getHeight();  

  if (options.offset) elementOffsets[1] += options.offset;

  return new Effect.Tween(null,
    scrollOffsets.top,
    elementOffsets[1] > max ? max : elementOffsets[1],
    options,
    function(p){ scrollTo(scrollOffsets.left, p.round()) }
  );
};

/* ------------- combination effects ------------- */

Effect.Fade = function(element) {
  element = $(element);
  var oldOpacity = element.getInlineOpacity();
  var options = Object.extend({
    from: element.getOpacity() || 1.0,
    to:   0.0,
    afterFinishInternal: function(effect) { 
      if (effect.options.to!=0) return;
      effect.element.hide().setStyle({opacity: oldOpacity}); 
    }
  }, arguments[1] || { });
  return new Effect.Opacity(element,options);
};

Effect.Appear = function(element) {
  element = $(element);
  var options = Object.extend({
  from: (element.getStyle('display') == 'none' ? 0.0 : element.getOpacity() || 0.0),
  to:   1.0,
  // force Safari to render floated elements properly
  afterFinishInternal: function(effect) {
    effect.element.forceRerendering();
  },
  beforeSetup: function(effect) {
    effect.element.setOpacity(effect.options.from).show(); 
  }}, arguments[1] || { });
  return new Effect.Opacity(element,options);
};

Effect.Puff = function(element) {
  element = $(element);
  var oldStyle = { 
    opacity: element.getInlineOpacity(), 
    position: element.getStyle('position'),
    top:  element.style.top,
    left: element.style.left,
    width: element.style.width,
    height: element.style.height
  };
  return new Effect.Parallel(
   [ new Effect.Scale(element, 200, 
      { sync: true, scaleFromCenter: true, scaleContent: true, restoreAfterFinish: true }), 
     new Effect.Opacity(element, { sync: true, to: 0.0 } ) ], 
     Object.extend({ duration: 1.0, 
      beforeSetupInternal: function(effect) {
        Position.absolutize(effect.effects[0].element)
      },
      afterFinishInternal: function(effect) {
         effect.effects[0].element.hide().setStyle(oldStyle); }
     }, arguments[1] || { })
   );
};

Effect.BlindUp = function(element) {
  element = $(element);
  element.makeClipping();
  return new Effect.Scale(element, 0,
    Object.extend({ scaleContent: false, 
      scaleX: false, 
      restoreAfterFinish: true,
      afterFinishInternal: function(effect) {
        effect.element.hide().undoClipping();
      } 
    }, arguments[1] || { })
  );
};

Effect.BlindDown = function(element) {
  element = $(element);
  var elementDimensions = element.getDimensions();
  return new Effect.Scale(element, 100, Object.extend({ 
    scaleContent: false, 
    scaleX: false,
    scaleFrom: 0,
    scaleMode: {originalHeight: elementDimensions.height, originalWidth: elementDimensions.width},
    restoreAfterFinish: true,
    afterSetup: function(effect) {
      effect.element.makeClipping().setStyle({height: '0px'}).show(); 
    },  
    afterFinishInternal: function(effect) {
      effect.element.undoClipping();
    }
  }, arguments[1] || { }));
};

Effect.SwitchOff = function(element) {
  element = $(element);
  var oldOpacity = element.getInlineOpacity();
  return new Effect.Appear(element, Object.extend({
    duration: 0.4,
    from: 0,
    transition: Effect.Transitions.flicker,
    afterFinishInternal: function(effect) {
      new Effect.Scale(effect.element, 1, { 
        duration: 0.3, scaleFromCenter: true,
        scaleX: false, scaleContent: false, restoreAfterFinish: true,
        beforeSetup: function(effect) { 
          effect.element.makePositioned().makeClipping();
        },
        afterFinishInternal: function(effect) {
          effect.element.hide().undoClipping().undoPositioned().setStyle({opacity: oldOpacity});
        }
      })
    }
  }, arguments[1] || { }));
};

Effect.DropOut = function(element) {
  element = $(element);
  var oldStyle = {
    top: element.getStyle('top'),
    left: element.getStyle('left'),
    opacity: element.getInlineOpacity() };
  return new Effect.Parallel(
    [ new Effect.Move(element, {x: 0, y: 100, sync: true }), 
      new Effect.Opacity(element, { sync: true, to: 0.0 }) ],
    Object.extend(
      { duration: 0.5,
        beforeSetup: function(effect) {
          effect.effects[0].element.makePositioned(); 
        },
        afterFinishInternal: function(effect) {
          effect.effects[0].element.hide().undoPositioned().setStyle(oldStyle);
        } 
      }, arguments[1] || { }));
};

Effect.Shake = function(element) {
  element = $(element);
  var options = Object.extend({
    distance: 20,
    duration: 0.5
  }, arguments[1] || {});
  var distance = parseFloat(options.distance);
  var split = parseFloat(options.duration) / 10.0;
  var oldStyle = {
    top: element.getStyle('top'),
    left: element.getStyle('left') };
    return new Effect.Move(element,
      { x:  distance, y: 0, duration: split, afterFinishInternal: function(effect) {
    new Effect.Move(effect.element,
      { x: -distance*2, y: 0, duration: split*2,  afterFinishInternal: function(effect) {
    new Effect.Move(effect.element,
      { x:  distance*2, y: 0, duration: split*2,  afterFinishInternal: function(effect) {
    new Effect.Move(effect.element,
      { x: -distance*2, y: 0, duration: split*2,  afterFinishInternal: function(effect) {
    new Effect.Move(effect.element,
      { x:  distance*2, y: 0, duration: split*2,  afterFinishInternal: function(effect) {
    new Effect.Move(effect.element,
      { x: -distance, y: 0, duration: split, afterFinishInternal: function(effect) {
        effect.element.undoPositioned().setStyle(oldStyle);
  }}) }}) }}) }}) }}) }});
};

Effect.SlideDown = function(element) {
  element = $(element).cleanWhitespace();
  // SlideDown need to have the content of the element wrapped in a container element with fixed height!
  var oldInnerBottom = element.down().getStyle('bottom');
  var elementDimensions = element.getDimensions();
  return new Effect.Scale(element, 100, Object.extend({ 
    scaleContent: false, 
    scaleX: false, 
    scaleFrom: window.opera ? 0 : 1,
    scaleMode: {originalHeight: elementDimensions.height, originalWidth: elementDimensions.width},
    restoreAfterFinish: true,
    afterSetup: function(effect) {
      effect.element.makePositioned();
      effect.element.down().makePositioned();
      if (window.opera) effect.element.setStyle({top: ''});
      effect.element.makeClipping().setStyle({height: '0px'}).show(); 
    },
    afterUpdateInternal: function(effect) {
      effect.element.down().setStyle({bottom:
        (effect.dims[0] - effect.element.clientHeight) + 'px' }); 
    },
    afterFinishInternal: function(effect) {
      effect.element.undoClipping().undoPositioned();
      effect.element.down().undoPositioned().setStyle({bottom: oldInnerBottom}); }
    }, arguments[1] || { })
  );
};

Effect.SlideUp = function(element) {
  element = $(element).cleanWhitespace();
  var oldInnerBottom = element.down().getStyle('bottom');
  var elementDimensions = element.getDimensions();
  return new Effect.Scale(element, window.opera ? 0 : 1,
   Object.extend({ scaleContent: false, 
    scaleX: false, 
    scaleMode: 'box',
    scaleFrom: 100,
    scaleMode: {originalHeight: elementDimensions.height, originalWidth: elementDimensions.width},
    restoreAfterFinish: true,
    afterSetup: function(effect) {
      effect.element.makePositioned();
      effect.element.down().makePositioned();
      if (window.opera) effect.element.setStyle({top: ''});
      effect.element.makeClipping().show();
    },  
    afterUpdateInternal: function(effect) {
      effect.element.down().setStyle({bottom:
        (effect.dims[0] - effect.element.clientHeight) + 'px' });
    },
    afterFinishInternal: function(effect) {
      effect.element.hide().undoClipping().undoPositioned();
      effect.element.down().undoPositioned().setStyle({bottom: oldInnerBottom});
    }
   }, arguments[1] || { })
  );
};

// Bug in opera makes the TD containing this element expand for a instance after finish 
Effect.Squish = function(element) {
  return new Effect.Scale(element, window.opera ? 1 : 0, { 
    restoreAfterFinish: true,
    beforeSetup: function(effect) {
      effect.element.makeClipping(); 
    },  
    afterFinishInternal: function(effect) {
      effect.element.hide().undoClipping(); 
    }
  });
};

Effect.Grow = function(element) {
  element = $(element);
  var options = Object.extend({
    direction: 'center',
    moveTransition: Effect.Transitions.sinoidal,
    scaleTransition: Effect.Transitions.sinoidal,
    opacityTransition: Effect.Transitions.full
  }, arguments[1] || { });
  var oldStyle = {
    top: element.style.top,
    left: element.style.left,
    height: element.style.height,
    width: element.style.width,
    opacity: element.getInlineOpacity() };

  var dims = element.getDimensions();    
  var initialMoveX, initialMoveY;
  var moveX, moveY;
  
  switch (options.direction) {
    case 'top-left':
      initialMoveX = initialMoveY = moveX = moveY = 0; 
      break;
    case 'top-right':
      initialMoveX = dims.width;
      initialMoveY = moveY = 0;
      moveX = -dims.width;
      break;
    case 'bottom-left':
      initialMoveX = moveX = 0;
      initialMoveY = dims.height;
      moveY = -dims.height;
      break;
    case 'bottom-right':
      initialMoveX = dims.width;
      initialMoveY = dims.height;
      moveX = -dims.width;
      moveY = -dims.height;
      break;
    case 'center':
      initialMoveX = dims.width / 2;
      initialMoveY = dims.height / 2;
      moveX = -dims.width / 2;
      moveY = -dims.height / 2;
      break;
  }
  
  return new Effect.Move(element, {
    x: initialMoveX,
    y: initialMoveY,
    duration: 0.01, 
    beforeSetup: function(effect) {
      effect.element.hide().makeClipping().makePositioned();
    },
    afterFinishInternal: function(effect) {
      new Effect.Parallel(
        [ new Effect.Opacity(effect.element, { sync: true, to: 1.0, from: 0.0, transition: options.opacityTransition }),
          new Effect.Move(effect.element, { x: moveX, y: moveY, sync: true, transition: options.moveTransition }),
          new Effect.Scale(effect.element, 100, {
            scaleMode: { originalHeight: dims.height, originalWidth: dims.width }, 
            sync: true, scaleFrom: window.opera ? 1 : 0, transition: options.scaleTransition, restoreAfterFinish: true})
        ], Object.extend({
             beforeSetup: function(effect) {
               effect.effects[0].element.setStyle({height: '0px'}).show(); 
             },
             afterFinishInternal: function(effect) {
               effect.effects[0].element.undoClipping().undoPositioned().setStyle(oldStyle); 
             }
           }, options)
      )
    }
  });
};

Effect.Shrink = function(element) {
  element = $(element);
  var options = Object.extend({
    direction: 'center',
    moveTransition: Effect.Transitions.sinoidal,
    scaleTransition: Effect.Transitions.sinoidal,
    opacityTransition: Effect.Transitions.none
  }, arguments[1] || { });
  var oldStyle = {
    top: element.style.top,
    left: element.style.left,
    height: element.style.height,
    width: element.style.width,
    opacity: element.getInlineOpacity() };

  var dims = element.getDimensions();
  var moveX, moveY;
  
  switch (options.direction) {
    case 'top-left':
      moveX = moveY = 0;
      break;
    case 'top-right':
      moveX = dims.width;
      moveY = 0;
      break;
    case 'bottom-left':
      moveX = 0;
      moveY = dims.height;
      break;
    case 'bottom-right':
      moveX = dims.width;
      moveY = dims.height;
      break;
    case 'center':  
      moveX = dims.width / 2;
      moveY = dims.height / 2;
      break;
  }
  
  return new Effect.Parallel(
    [ new Effect.Opacity(element, { sync: true, to: 0.0, from: 1.0, transition: options.opacityTransition }),
      new Effect.Scale(element, window.opera ? 1 : 0, { sync: true, transition: options.scaleTransition, restoreAfterFinish: true}),
      new Effect.Move(element, { x: moveX, y: moveY, sync: true, transition: options.moveTransition })
    ], Object.extend({            
         beforeStartInternal: function(effect) {
           effect.effects[0].element.makePositioned().makeClipping(); 
         },
         afterFinishInternal: function(effect) {
           effect.effects[0].element.hide().undoClipping().undoPositioned().setStyle(oldStyle); }
       }, options)
  );
};

Effect.Pulsate = function(element) {
  element = $(element);
  var options    = arguments[1] || { };
  var oldOpacity = element.getInlineOpacity();
  var transition = options.transition || Effect.Transitions.sinoidal;
  var reverser   = function(pos){ return transition(1-Effect.Transitions.pulse(pos, options.pulses)) };
  reverser.bind(transition);
  return new Effect.Opacity(element, 
    Object.extend(Object.extend({  duration: 2.0, from: 0,
      afterFinishInternal: function(effect) { effect.element.setStyle({opacity: oldOpacity}); }
    }, options), {transition: reverser}));
};

Effect.Fold = function(element) {
  element = $(element);
  var oldStyle = {
    top: element.style.top,
    left: element.style.left,
    width: element.style.width,
    height: element.style.height };
  element.makeClipping();
  return new Effect.Scale(element, 5, Object.extend({   
    scaleContent: false,
    scaleX: false,
    afterFinishInternal: function(effect) {
    new Effect.Scale(element, 1, { 
      scaleContent: false, 
      scaleY: false,
      afterFinishInternal: function(effect) {
        effect.element.hide().undoClipping().setStyle(oldStyle);
      } });
  }}, arguments[1] || { }));
};

Effect.Morph = Class.create(Effect.Base, {
  initialize: function(element) {
    this.element = $(element);
    if (!this.element) throw(Effect._elementDoesNotExistError);
    var options = Object.extend({
      style: { }
    }, arguments[1] || { });
    
    if (!Object.isString(options.style)) this.style = $H(options.style);
    else {
      if (options.style.include(':'))
        this.style = options.style.parseStyle();
      else {
        this.element.addClassName(options.style);
        this.style = $H(this.element.getStyles());
        this.element.removeClassName(options.style);
        var css = this.element.getStyles();
        this.style = this.style.reject(function(style) {
          return style.value == css[style.key];
        });
        options.afterFinishInternal = function(effect) {
          effect.element.addClassName(effect.options.style);
          effect.transforms.each(function(transform) {
            effect.element.style[transform.style] = '';
          });
        }
      }
    }
    this.start(options);
  },
  
  setup: function(){
    function parseColor(color){
      if (!color || ['rgba(0, 0, 0, 0)','transparent'].include(color)) color = '#ffffff';
      color = color.parseColor();
      return $R(0,2).map(function(i){
        return parseInt( color.slice(i*2+1,i*2+3), 16 ) 
      });
    }
    this.transforms = this.style.map(function(pair){
      var property = pair[0], value = pair[1], unit = null;

      if (value.parseColor('#zzzzzz') != '#zzzzzz') {
        value = value.parseColor();
        unit  = 'color';
      } else if (property == 'opacity') {
        value = parseFloat(value);
        if (Prototype.Browser.IE && (!this.element.currentStyle.hasLayout))
          this.element.setStyle({zoom: 1});
      } else if (Element.CSS_LENGTH.test(value)) {
          var components = value.match(/^([\+\-]?[0-9\.]+)(.*)$/);
          value = parseFloat(components[1]);
          unit = (components.length == 3) ? components[2] : null;
      }

      var originalValue = this.element.getStyle(property);
      return { 
        style: property.camelize(), 
        originalValue: unit=='color' ? parseColor(originalValue) : parseFloat(originalValue || 0), 
        targetValue: unit=='color' ? parseColor(value) : value,
        unit: unit
      };
    }.bind(this)).reject(function(transform){
      return (
        (transform.originalValue == transform.targetValue) ||
        (
          transform.unit != 'color' &&
          (isNaN(transform.originalValue) || isNaN(transform.targetValue))
        )
      )
    });
  },
  update: function(position) {
    var style = { }, transform, i = this.transforms.length;
    while(i--)
      style[(transform = this.transforms[i]).style] = 
        transform.unit=='color' ? '#'+
          (Math.round(transform.originalValue[0]+
            (transform.targetValue[0]-transform.originalValue[0])*position)).toColorPart() +
          (Math.round(transform.originalValue[1]+
            (transform.targetValue[1]-transform.originalValue[1])*position)).toColorPart() +
          (Math.round(transform.originalValue[2]+
            (transform.targetValue[2]-transform.originalValue[2])*position)).toColorPart() :
        (transform.originalValue +
          (transform.targetValue - transform.originalValue) * position).toFixed(3) + 
            (transform.unit === null ? '' : transform.unit);
    this.element.setStyle(style, true);
  }
});

Effect.Transform = Class.create({
  initialize: function(tracks){
    this.tracks  = [];
    this.options = arguments[1] || { };
    this.addTracks(tracks);
  },
  addTracks: function(tracks){
    tracks.each(function(track){
      track = $H(track);
      var data = track.values().first();
      this.tracks.push($H({
        ids:     track.keys().first(),
        effect:  Effect.Morph,
        options: { style: data }
      }));
    }.bind(this));
    return this;
  },
  play: function(){
    return new Effect.Parallel(
      this.tracks.map(function(track){
        var ids = track.get('ids'), effect = track.get('effect'), options = track.get('options');
        var elements = [$(ids) || $$(ids)].flatten();
        return elements.map(function(e){ return new effect(e, Object.extend({ sync:true }, options)) });
      }).flatten(),
      this.options
    );
  }
});

Element.CSS_PROPERTIES = $w(
  'backgroundColor backgroundPosition borderBottomColor borderBottomStyle ' + 
  'borderBottomWidth borderLeftColor borderLeftStyle borderLeftWidth ' +
  'borderRightColor borderRightStyle borderRightWidth borderSpacing ' +
  'borderTopColor borderTopStyle borderTopWidth bottom clip color ' +
  'fontSize fontWeight height left letterSpacing lineHeight ' +
  'marginBottom marginLeft marginRight marginTop markerOffset maxHeight '+
  'maxWidth minHeight minWidth opacity outlineColor outlineOffset ' +
  'outlineWidth paddingBottom paddingLeft paddingRight paddingTop ' +
  'right textIndent top width wordSpacing zIndex');
  
Element.CSS_LENGTH = /^(([\+\-]?[0-9\.]+)(em|ex|px|in|cm|mm|pt|pc|\%))|0$/;

String.__parseStyleElement = document.createElement('div');
String.prototype.parseStyle = function(){
  var style, styleRules = $H();
  if (Prototype.Browser.WebKit)
    style = new Element('div',{style:this}).style;
  else {
    String.__parseStyleElement.innerHTML = '<div style="' + this + '"></div>';
    style = String.__parseStyleElement.childNodes[0].style;
  }
  
  Element.CSS_PROPERTIES.each(function(property){
    if (style[property]) styleRules.set(property, style[property]); 
  });
  
  if (Prototype.Browser.IE && this.include('opacity'))
    styleRules.set('opacity', this.match(/opacity:\s*((?:0|1)?(?:\.\d*)?)/)[1]);

  return styleRules;
};

if (document.defaultView && document.defaultView.getComputedStyle) {
  Element.getStyles = function(element) {
    var css = document.defaultView.getComputedStyle($(element), null);
    return Element.CSS_PROPERTIES.inject({ }, function(styles, property) {
      styles[property] = css[property];
      return styles;
    });
  };
} else {
  Element.getStyles = function(element) {
    element = $(element);
    var css = element.currentStyle, styles;
    styles = Element.CSS_PROPERTIES.inject({ }, function(results, property) {
      results[property] = css[property];
      return results;
    });
    if (!styles.opacity) styles.opacity = element.getOpacity();
    return styles;
  };
};

Effect.Methods = {
  morph: function(element, style) {
    element = $(element);
    new Effect.Morph(element, Object.extend({ style: style }, arguments[2] || { }));
    return element;
  },
  visualEffect: function(element, effect, options) {
    element = $(element)
    var s = effect.dasherize().camelize(), klass = s.charAt(0).toUpperCase() + s.substring(1);
    new Effect[klass](element, options);
    return element;
  },
  highlight: function(element, options) {
    element = $(element);
    new Effect.Highlight(element, options);
    return element;
  }
};

$w('fade appear grow shrink fold blindUp blindDown slideUp slideDown '+
  'pulsate shake puff squish switchOff dropOut').each(
  function(effect) { 
    Effect.Methods[effect] = function(element, options){
      element = $(element);
      Effect[effect.charAt(0).toUpperCase() + effect.substring(1)](element, options);
      return element;
    }
  }
);

$w('getInlineOpacity forceRerendering setContentZoom collectTextNodes collectTextNodesIgnoreClass getStyles').each( 
  function(f) { Effect.Methods[f] = Element[f]; }
);

Element.addMethods(Effect.Methods);


// Copyright (c) 2005-2008 Thomas Fuchs (http://script.aculo.us, http://mir.aculo.us)
//           (c) 2005-2007 Sammi Williams (http://www.oriontransfer.co.nz, sammi@oriontransfer.co.nz)
// 
// script.aculo.us is freely distributable under the terms of an MIT-style license.
// For details, see the script.aculo.us web site: http://script.aculo.us/

if(Object.isUndefined(Effect))
  throw("dragdrop.js requires including script.aculo.us' effects.js library");

var Droppables = {
  drops: [],

  remove: function(element) {
    this.drops = this.drops.reject(function(d) { return d.element==$(element) });
  },

  add: function(element) {
    element = $(element);
    var options = Object.extend({
      greedy:     true,
      hoverclass: null,
      tree:       false
    }, arguments[1] || { });

    // cache containers
    if(options.containment) {
      options._containers = [];
      var containment = options.containment;
      if(Object.isArray(containment)) {
        containment.each( function(c) { options._containers.push($(c)) });
      } else {
        options._containers.push($(containment));
      }
    }
    
    if(options.accept) options.accept = [options.accept].flatten();

    Element.makePositioned(element); // fix IE
    options.element = element;

    this.drops.push(options);
  },
  
  findDeepestChild: function(drops) {
    deepest = drops[0];
      
    for (i = 1; i < drops.length; ++i)
      if (Element.isParent(drops[i].element, deepest.element))
        deepest = drops[i];
    
    return deepest;
  },

  isContained: function(element, drop) {
    var containmentNode;
    if(drop.tree) {
      containmentNode = element.treeNode; 
    } else {
      containmentNode = element.parentNode;
    }
    return drop._containers.detect(function(c) { return containmentNode == c });
  },
  
  isAffected: function(point, element, drop) {
    return (
      (drop.element!=element) &&
      ((!drop._containers) ||
        this.isContained(element, drop)) &&
      ((!drop.accept) ||
        (Element.classNames(element).detect( 
          function(v) { return drop.accept.include(v) } ) )) &&
      Position.within(drop.element, point[0], point[1]) );
  },

  deactivate: function(drop) {
    if(drop.hoverclass)
      Element.removeClassName(drop.element, drop.hoverclass);
    this.last_active = null;
  },

  activate: function(drop) {
    if(drop.hoverclass)
      Element.addClassName(drop.element, drop.hoverclass);
    this.last_active = drop;
  },

  show: function(point, element) {
    if(!this.drops.length) return;
    var drop, affected = [];
    
    this.drops.each( function(drop) {
      if(Droppables.isAffected(point, element, drop))
        affected.push(drop);
    });
        
    if(affected.length>0)
      drop = Droppables.findDeepestChild(affected);

    if(this.last_active && this.last_active != drop) this.deactivate(this.last_active);
    if (drop) {
      Position.within(drop.element, point[0], point[1]);
      if(drop.onHover)
        drop.onHover(element, drop.element, Position.overlap(drop.overlap, drop.element));
      
      if (drop != this.last_active) Droppables.activate(drop);
    }
  },

  fire: function(event, element) {
    if(!this.last_active) return;
    Position.prepare();

    if (this.isAffected([Event.pointerX(event), Event.pointerY(event)], element, this.last_active))
      if (this.last_active.onDrop) {
        this.last_active.onDrop(element, this.last_active.element, event); 
        return true; 
      }
  },

  reset: function() {
    if(this.last_active)
      this.deactivate(this.last_active);
  }
}

var Draggables = {
  drags: [],
  observers: [],
  
  register: function(draggable) {
    if(this.drags.length == 0) {
      this.eventMouseUp   = this.endDrag.bindAsEventListener(this);
      this.eventMouseMove = this.updateDrag.bindAsEventListener(this);
      this.eventKeypress  = this.keyPress.bindAsEventListener(this);
      
      Event.observe(document, "mouseup", this.eventMouseUp);
      Event.observe(document, "mousemove", this.eventMouseMove);
      Event.observe(document, "keypress", this.eventKeypress);
    }
    this.drags.push(draggable);
  },
  
  unregister: function(draggable) {
    this.drags = this.drags.reject(function(d) { return d==draggable });
    if(this.drags.length == 0) {
      Event.stopObserving(document, "mouseup", this.eventMouseUp);
      Event.stopObserving(document, "mousemove", this.eventMouseMove);
      Event.stopObserving(document, "keypress", this.eventKeypress);
    }
  },
  
  activate: function(draggable) {
    if(draggable.options.delay) { 
      this._timeout = setTimeout(function() { 
        Draggables._timeout = null; 
        window.focus(); 
        Draggables.activeDraggable = draggable; 
      }.bind(this), draggable.options.delay); 
    } else {
      window.focus(); // allows keypress events if window isn't currently focused, fails for Safari
      this.activeDraggable = draggable;
    }
  },
  
  deactivate: function() {
    this.activeDraggable = null;
  },
  
  updateDrag: function(event) {
    if(!this.activeDraggable) return;
    var pointer = [Event.pointerX(event), Event.pointerY(event)];
    // Mozilla-based browsers fire successive mousemove events with
    // the same coordinates, prevent needless redrawing (moz bug?)
    if(this._lastPointer && (this._lastPointer.inspect() == pointer.inspect())) return;
    this._lastPointer = pointer;
    
    this.activeDraggable.updateDrag(event, pointer);
  },
  
  endDrag: function(event) {
    if(this._timeout) { 
      clearTimeout(this._timeout); 
      this._timeout = null; 
    }
    if(!this.activeDraggable) return;
    this._lastPointer = null;
    this.activeDraggable.endDrag(event);
    this.activeDraggable = null;
  },
  
  keyPress: function(event) {
    if(this.activeDraggable)
      this.activeDraggable.keyPress(event);
  },
  
  addObserver: function(observer) {
    this.observers.push(observer);
    this._cacheObserverCallbacks();
  },
  
  removeObserver: function(element) {  // element instead of observer fixes mem leaks
    this.observers = this.observers.reject( function(o) { return o.element==element });
    this._cacheObserverCallbacks();
  },
  
  notify: function(eventName, draggable, event) {  // 'onStart', 'onEnd', 'onDrag'
    if(this[eventName+'Count'] > 0)
      this.observers.each( function(o) {
        if(o[eventName]) o[eventName](eventName, draggable, event);
      });
    if(draggable.options[eventName]) draggable.options[eventName](draggable, event);
  },
  
  _cacheObserverCallbacks: function() {
    ['onStart','onEnd','onDrag'].each( function(eventName) {
      Draggables[eventName+'Count'] = Draggables.observers.select(
        function(o) { return o[eventName]; }
      ).length;
    });
  }
}

/*--------------------------------------------------------------------------*/

var Draggable = Class.create({
  initialize: function(element) {
    var defaults = {
      handle: false,
      reverteffect: function(element, top_offset, left_offset) {
        var dur = Math.sqrt(Math.abs(top_offset^2)+Math.abs(left_offset^2))*0.02;
        new Effect.Move(element, { x: -left_offset, y: -top_offset, duration: dur,
          queue: {scope:'_draggable', position:'end'}
        });
      },
      endeffect: function(element) {
        var toOpacity = Object.isNumber(element._opacity) ? element._opacity : 1.0;
        new Effect.Opacity(element, {duration:0.2, from:0.7, to:toOpacity, 
          queue: {scope:'_draggable', position:'end'},
          afterFinish: function(){ 
            Draggable._dragging[element] = false 
          }
        }); 
      },
      zindex: 1000,
      revert: false,
      quiet: false,
      scroll: false,
      scrollSensitivity: 20,
      scrollSpeed: 15,
      snap: false,  // false, or xy or [x,y] or function(x,y){ return [x,y] }
      delay: 0
    };
    
    if(!arguments[1] || Object.isUndefined(arguments[1].endeffect))
      Object.extend(defaults, {
        starteffect: function(element) {
          element._opacity = Element.getOpacity(element);
          Draggable._dragging[element] = true;
          new Effect.Opacity(element, {duration:0.2, from:element._opacity, to:0.7}); 
        }
      });
    
    var options = Object.extend(defaults, arguments[1] || { });

    this.element = $(element);
    
    if(options.handle && Object.isString(options.handle))
      this.handle = this.element.down('.'+options.handle, 0);
    
    if(!this.handle) this.handle = $(options.handle);
    if(!this.handle) this.handle = this.element;
    
    if(options.scroll && !options.scroll.scrollTo && !options.scroll.outerHTML) {
      options.scroll = $(options.scroll);
      this._isScrollChild = Element.childOf(this.element, options.scroll);
    }

    Element.makePositioned(this.element); // fix IE    

    this.options  = options;
    this.dragging = false;   

    this.eventMouseDown = this.initDrag.bindAsEventListener(this);
    Event.observe(this.handle, "mousedown", this.eventMouseDown);
    
    Draggables.register(this);
  },
  
  destroy: function() {
    Event.stopObserving(this.handle, "mousedown", this.eventMouseDown);
    Draggables.unregister(this);
  },
  
  currentDelta: function() {
    return([
      parseInt(Element.getStyle(this.element,'left') || '0'),
      parseInt(Element.getStyle(this.element,'top') || '0')]);
  },
  
  initDrag: function(event) {
    if(!Object.isUndefined(Draggable._dragging[this.element]) &&
      Draggable._dragging[this.element]) return;
    if(Event.isLeftClick(event)) {    
      // abort on form elements, fixes a Firefox issue
      var src = Event.element(event);
      if((tag_name = src.tagName.toUpperCase()) && (
        tag_name=='INPUT' ||
        tag_name=='SELECT' ||
        tag_name=='OPTION' ||
        tag_name=='BUTTON' ||
        tag_name=='TEXTAREA')) return;
        
      var pointer = [Event.pointerX(event), Event.pointerY(event)];
      var pos     = Position.cumulativeOffset(this.element);
      this.offset = [0,1].map( function(i) { return (pointer[i] - pos[i]) });
      
      Draggables.activate(this);
      Event.stop(event);
    }
  },
  
  startDrag: function(event) {
    this.dragging = true;
    if(!this.delta)
      this.delta = this.currentDelta();
    
    if(this.options.zindex) {
      this.originalZ = parseInt(Element.getStyle(this.element,'z-index') || 0);
      this.element.style.zIndex = this.options.zindex;
    }
    
    if(this.options.ghosting) {
      this._clone = this.element.cloneNode(true);
      this.element._originallyAbsolute = (this.element.getStyle('position') == 'absolute');
      if (!this.element._originallyAbsolute)
        Position.absolutize(this.element);
      this.element.parentNode.insertBefore(this._clone, this.element);
    }
    
    if(this.options.scroll) {
      if (this.options.scroll == window) {
        var where = this._getWindowScroll(this.options.scroll);
        this.originalScrollLeft = where.left;
        this.originalScrollTop = where.top;
      } else {
        this.originalScrollLeft = this.options.scroll.scrollLeft;
        this.originalScrollTop = this.options.scroll.scrollTop;
      }
    }
    
    Draggables.notify('onStart', this, event);
        
    if(this.options.starteffect) this.options.starteffect(this.element);
  },
  
  updateDrag: function(event, pointer) {
    if(!this.dragging) this.startDrag(event);
    
    if(!this.options.quiet){
      Position.prepare();
      Droppables.show(pointer, this.element);
    }
    
    Draggables.notify('onDrag', this, event);
    
    this.draw(pointer);
    if(this.options.change) this.options.change(this);
    
    if(this.options.scroll) {
      this.stopScrolling();
      
      var p;
      if (this.options.scroll == window) {
        with(this._getWindowScroll(this.options.scroll)) { p = [ left, top, left+width, top+height ]; }
      } else {
        p = Position.page(this.options.scroll);
        p[0] += this.options.scroll.scrollLeft + Position.deltaX;
        p[1] += this.options.scroll.scrollTop + Position.deltaY;
        p.push(p[0]+this.options.scroll.offsetWidth);
        p.push(p[1]+this.options.scroll.offsetHeight);
      }
      var speed = [0,0];
      if(pointer[0] < (p[0]+this.options.scrollSensitivity)) speed[0] = pointer[0]-(p[0]+this.options.scrollSensitivity);
      if(pointer[1] < (p[1]+this.options.scrollSensitivity)) speed[1] = pointer[1]-(p[1]+this.options.scrollSensitivity);
      if(pointer[0] > (p[2]-this.options.scrollSensitivity)) speed[0] = pointer[0]-(p[2]-this.options.scrollSensitivity);
      if(pointer[1] > (p[3]-this.options.scrollSensitivity)) speed[1] = pointer[1]-(p[3]-this.options.scrollSensitivity);
      this.startScrolling(speed);
    }
    
    // fix AppleWebKit rendering
    if(Prototype.Browser.WebKit) window.scrollBy(0,0);
    
    Event.stop(event);
  },
  
  finishDrag: function(event, success) {
    this.dragging = false;
    
    if(this.options.quiet){
      Position.prepare();
      var pointer = [Event.pointerX(event), Event.pointerY(event)];
      Droppables.show(pointer, this.element);
    }

    if(this.options.ghosting) {
      if (!this.element._originallyAbsolute)
        Position.relativize(this.element);
      delete this.element._originallyAbsolute;
      Element.remove(this._clone);
      this._clone = null;
    }

    var dropped = false; 
    if(success) { 
      dropped = Droppables.fire(event, this.element); 
      if (!dropped) dropped = false; 
    }
    if(dropped && this.options.onDropped) this.options.onDropped(this.element);
    Draggables.notify('onEnd', this, event);

    var revert = this.options.revert;
    if(revert && Object.isFunction(revert)) revert = revert(this.element);
    
    var d = this.currentDelta();
    if(revert && this.options.reverteffect) {
      if (dropped == 0 || revert != 'failure')
        this.options.reverteffect(this.element,
          d[1]-this.delta[1], d[0]-this.delta[0]);
    } else {
      this.delta = d;
    }

    if(this.options.zindex)
      this.element.style.zIndex = this.originalZ;

    if(this.options.endeffect) 
      this.options.endeffect(this.element);
      
    Draggables.deactivate(this);
    Droppables.reset();
  },
  
  keyPress: function(event) {
    if(event.keyCode!=Event.KEY_ESC) return;
    this.finishDrag(event, false);
    Event.stop(event);
  },
  
  endDrag: function(event) {
    if(!this.dragging) return;
    this.stopScrolling();
    this.finishDrag(event, true);
    Event.stop(event);
  },
  
  draw: function(point) {
    var pos = Position.cumulativeOffset(this.element);
    if(this.options.ghosting) {
      var r   = Position.realOffset(this.element);
      pos[0] += r[0] - Position.deltaX; pos[1] += r[1] - Position.deltaY;
    }
    
    var d = this.currentDelta();
    pos[0] -= d[0]; pos[1] -= d[1];
    
    if(this.options.scroll && (this.options.scroll != window && this._isScrollChild)) {
      pos[0] -= this.options.scroll.scrollLeft-this.originalScrollLeft;
      pos[1] -= this.options.scroll.scrollTop-this.originalScrollTop;
    }
    
    var p = [0,1].map(function(i){ 
      return (point[i]-pos[i]-this.offset[i]) 
    }.bind(this));
    
    if(this.options.snap) {
      if(Object.isFunction(this.options.snap)) {
        p = this.options.snap(p[0],p[1],this);
      } else {
      if(Object.isArray(this.options.snap)) {
        p = p.map( function(v, i) {
          return (v/this.options.snap[i]).round()*this.options.snap[i] }.bind(this))
      } else {
        p = p.map( function(v) {
          return (v/this.options.snap).round()*this.options.snap }.bind(this))
      }
    }}
    
    var style = this.element.style;
    if((!this.options.constraint) || (this.options.constraint=='horizontal'))
      style.left = p[0] + "px";
    if((!this.options.constraint) || (this.options.constraint=='vertical'))
      style.top  = p[1] + "px";
    
    if(style.visibility=="hidden") style.visibility = ""; // fix gecko rendering
  },
  
  stopScrolling: function() {
    if(this.scrollInterval) {
      clearInterval(this.scrollInterval);
      this.scrollInterval = null;
      Draggables._lastScrollPointer = null;
    }
  },
  
  startScrolling: function(speed) {
    if(!(speed[0] || speed[1])) return;
    this.scrollSpeed = [speed[0]*this.options.scrollSpeed,speed[1]*this.options.scrollSpeed];
    this.lastScrolled = new Date();
    this.scrollInterval = setInterval(this.scroll.bind(this), 10);
  },
  
  scroll: function() {
    var current = new Date();
    var delta = current - this.lastScrolled;
    this.lastScrolled = current;
    if(this.options.scroll == window) {
      with (this._getWindowScroll(this.options.scroll)) {
        if (this.scrollSpeed[0] || this.scrollSpeed[1]) {
          var d = delta / 1000;
          this.options.scroll.scrollTo( left + d*this.scrollSpeed[0], top + d*this.scrollSpeed[1] );
        }
      }
    } else {
      this.options.scroll.scrollLeft += this.scrollSpeed[0] * delta / 1000;
      this.options.scroll.scrollTop  += this.scrollSpeed[1] * delta / 1000;
    }
    
    Position.prepare();
    Droppables.show(Draggables._lastPointer, this.element);
    Draggables.notify('onDrag', this);
    if (this._isScrollChild) {
      Draggables._lastScrollPointer = Draggables._lastScrollPointer || $A(Draggables._lastPointer);
      Draggables._lastScrollPointer[0] += this.scrollSpeed[0] * delta / 1000;
      Draggables._lastScrollPointer[1] += this.scrollSpeed[1] * delta / 1000;
      if (Draggables._lastScrollPointer[0] < 0)
        Draggables._lastScrollPointer[0] = 0;
      if (Draggables._lastScrollPointer[1] < 0)
        Draggables._lastScrollPointer[1] = 0;
      this.draw(Draggables._lastScrollPointer);
    }
    
    if(this.options.change) this.options.change(this);
  },
  
  _getWindowScroll: function(w) {
    var T, L, W, H;
    with (w.document) {
      if (w.document.documentElement && documentElement.scrollTop) {
        T = documentElement.scrollTop;
        L = documentElement.scrollLeft;
      } else if (w.document.body) {
        T = body.scrollTop;
        L = body.scrollLeft;
      }
      if (w.innerWidth) {
        W = w.innerWidth;
        H = w.innerHeight;
      } else if (w.document.documentElement && documentElement.clientWidth) {
        W = documentElement.clientWidth;
        H = documentElement.clientHeight;
      } else {
        W = body.offsetWidth;
        H = body.offsetHeight
      }
    }
    return { top: T, left: L, width: W, height: H };
  }
});

Draggable._dragging = { };

/*--------------------------------------------------------------------------*/

var SortableObserver = Class.create({
  initialize: function(element, observer) {
    this.element   = $(element);
    this.observer  = observer;
    this.lastValue = Sortable.serialize(this.element);
  },
  
  onStart: function() {
    this.lastValue = Sortable.serialize(this.element);
  },
  
  onEnd: function() {
    Sortable.unmark();
    if(this.lastValue != Sortable.serialize(this.element))
      this.observer(this.element)
  }
});

var Sortable = {
  SERIALIZE_RULE: /^[^_\-](?:[A-Za-z0-9\-\_]*)[_](.*)$/,
  
  sortables: { },
  
  _findRootElement: function(element) {
    while (element.tagName.toUpperCase() != "BODY") {  
      if(element.id && Sortable.sortables[element.id]) return element;
      element = element.parentNode;
    }
  },

  options: function(element) {
    element = Sortable._findRootElement($(element));
    if(!element) return;
    return Sortable.sortables[element.id];
  },
  
  destroy: function(element){
    var s = Sortable.options(element);
    
    if(s) {
      Draggables.removeObserver(s.element);
      s.droppables.each(function(d){ Droppables.remove(d) });
      s.draggables.invoke('destroy');
      
      delete Sortable.sortables[s.element.id];
    }
  },

  create: function(element) {
    element = $(element);
    var options = Object.extend({ 
      element:     element,
      tag:         'li',       // assumes li children, override with tag: 'tagname'
      dropOnEmpty: false,
      tree:        false,
      treeTag:     'ul',
      overlap:     'vertical', // one of 'vertical', 'horizontal'
      constraint:  'vertical', // one of 'vertical', 'horizontal', false
      containment: element,    // also takes array of elements (or id's); or false
      handle:      false,      // or a CSS class
      only:        false,
      delay:       0,
      hoverclass:  null,
      ghosting:    false,
      quiet:       false, 
      scroll:      false,
      scrollSensitivity: 20,
      scrollSpeed: 15,
      format:      this.SERIALIZE_RULE,
      
      // these take arrays of elements or ids and can be 
      // used for better initialization performance
      elements:    false,
      handles:     false,
      
      onChange:    Prototype.emptyFunction,
      onUpdate:    Prototype.emptyFunction
    }, arguments[1] || { });

    // clear any old sortable with same element
    this.destroy(element);

    // build options for the draggables
    var options_for_draggable = {
      revert:      true,
      quiet:       options.quiet,
      scroll:      options.scroll,
      scrollSpeed: options.scrollSpeed,
      scrollSensitivity: options.scrollSensitivity,
      delay:       options.delay,
      ghosting:    options.ghosting,
      constraint:  options.constraint,
      handle:      options.handle };

    if(options.starteffect)
      options_for_draggable.starteffect = options.starteffect;

    if(options.reverteffect)
      options_for_draggable.reverteffect = options.reverteffect;
    else
      if(options.ghosting) options_for_draggable.reverteffect = function(element) {
        element.style.top  = 0;
        element.style.left = 0;
      };

    if(options.endeffect)
      options_for_draggable.endeffect = options.endeffect;

    if(options.zindex)
      options_for_draggable.zindex = options.zindex;

    // build options for the droppables  
    var options_for_droppable = {
      overlap:     options.overlap,
      containment: options.containment,
      tree:        options.tree,
      hoverclass:  options.hoverclass,
      onHover:     Sortable.onHover
    }
    
    var options_for_tree = {
      onHover:      Sortable.onEmptyHover,
      overlap:      options.overlap,
      containment:  options.containment,
      hoverclass:   options.hoverclass
    }

    // fix for gecko engine
    Element.cleanWhitespace(element); 

    options.draggables = [];
    options.droppables = [];

    // drop on empty handling
    if(options.dropOnEmpty || options.tree) {
      Droppables.add(element, options_for_tree);
      options.droppables.push(element);
    }

    (options.elements || this.findElements(element, options) || []).each( function(e,i) {
      var handle = options.handles ? $(options.handles[i]) :
        (options.handle ? $(e).select('.' + options.handle)[0] : e); 
      options.draggables.push(
        new Draggable(e, Object.extend(options_for_draggable, { handle: handle })));
      Droppables.add(e, options_for_droppable);
      if(options.tree) e.treeNode = element;
      options.droppables.push(e);      
    });
    
    if(options.tree) {
      (Sortable.findTreeElements(element, options) || []).each( function(e) {
        Droppables.add(e, options_for_tree);
        e.treeNode = element;
        options.droppables.push(e);
      });
    }

    // keep reference
    this.sortables[element.id] = options;

    // for onupdate
    Draggables.addObserver(new SortableObserver(element, options.onUpdate));

  },

  // return all suitable-for-sortable elements in a guaranteed order
  findElements: function(element, options) {
    return Element.findChildren(
      element, options.only, options.tree ? true : false, options.tag);
  },
  
  findTreeElements: function(element, options) {
    return Element.findChildren(
      element, options.only, options.tree ? true : false, options.treeTag);
  },

  onHover: function(element, dropon, overlap) {
    if(Element.isParent(dropon, element)) return;

    if(overlap > .33 && overlap < .66 && Sortable.options(dropon).tree) {
      return;
    } else if(overlap>0.5) {
      Sortable.mark(dropon, 'before');
      if(dropon.previousSibling != element) {
        var oldParentNode = element.parentNode;
        element.style.visibility = "hidden"; // fix gecko rendering
        dropon.parentNode.insertBefore(element, dropon);
        if(dropon.parentNode!=oldParentNode) 
          Sortable.options(oldParentNode).onChange(element);
        Sortable.options(dropon.parentNode).onChange(element);
      }
    } else {
      Sortable.mark(dropon, 'after');
      var nextElement = dropon.nextSibling || null;
      if(nextElement != element) {
        var oldParentNode = element.parentNode;
        element.style.visibility = "hidden"; // fix gecko rendering
        dropon.parentNode.insertBefore(element, nextElement);
        if(dropon.parentNode!=oldParentNode) 
          Sortable.options(oldParentNode).onChange(element);
        Sortable.options(dropon.parentNode).onChange(element);
      }
    }
  },
  
  onEmptyHover: function(element, dropon, overlap) {
    var oldParentNode = element.parentNode;
    var droponOptions = Sortable.options(dropon);
        
    if(!Element.isParent(dropon, element)) {
      var index;
      
      var children = Sortable.findElements(dropon, {tag: droponOptions.tag, only: droponOptions.only});
      var child = null;
            
      if(children) {
        var offset = Element.offsetSize(dropon, droponOptions.overlap) * (1.0 - overlap);
        
        for (index = 0; index < children.length; index += 1) {
          if (offset - Element.offsetSize (children[index], droponOptions.overlap) >= 0) {
            offset -= Element.offsetSize (children[index], droponOptions.overlap);
          } else if (offset - (Element.offsetSize (children[index], droponOptions.overlap) / 2) >= 0) {
            child = index + 1 < children.length ? children[index + 1] : null;
            break;
          } else {
            child = children[index];
            break;
          }
        }
      }
      
      dropon.insertBefore(element, child);
      
      Sortable.options(oldParentNode).onChange(element);
      droponOptions.onChange(element);
    }
  },

  unmark: function() {
    if(Sortable._marker) Sortable._marker.hide();
  },

  mark: function(dropon, position) {
    // mark on ghosting only
    var sortable = Sortable.options(dropon.parentNode);
    if(sortable && !sortable.ghosting) return; 

    if(!Sortable._marker) {
      Sortable._marker = 
        ($('dropmarker') || Element.extend(document.createElement('DIV'))).
          hide().addClassName('dropmarker').setStyle({position:'absolute'});
      document.getElementsByTagName("body").item(0).appendChild(Sortable._marker);
    }    
    var offsets = Position.cumulativeOffset(dropon);
    Sortable._marker.setStyle({left: offsets[0]+'px', top: offsets[1] + 'px'});
    
    if(position=='after')
      if(sortable.overlap == 'horizontal') 
        Sortable._marker.setStyle({left: (offsets[0]+dropon.clientWidth) + 'px'});
      else
        Sortable._marker.setStyle({top: (offsets[1]+dropon.clientHeight) + 'px'});
    
    Sortable._marker.show();
  },
  
  _tree: function(element, options, parent) {
    var children = Sortable.findElements(element, options) || [];
  
    for (var i = 0; i < children.length; ++i) {
      var match = children[i].id.match(options.format);

      if (!match) continue;
      
      var child = {
        id: encodeURIComponent(match ? match[1] : null),
        element: element,
        parent: parent,
        children: [],
        position: parent.children.length,
        container: $(children[i]).down(options.treeTag)
      }
      
      /* Get the element containing the children and recurse over it */
      if (child.container)
        this._tree(child.container, options, child)
      
      parent.children.push (child);
    }

    return parent; 
  },

  tree: function(element) {
    element = $(element);
    var sortableOptions = this.options(element);
    var options = Object.extend({
      tag: sortableOptions.tag,
      treeTag: sortableOptions.treeTag,
      only: sortableOptions.only,
      name: element.id,
      format: sortableOptions.format
    }, arguments[1] || { });
    
    var root = {
      id: null,
      parent: null,
      children: [],
      container: element,
      position: 0
    }
    
    return Sortable._tree(element, options, root);
  },

  /* Construct a [i] index for a particular node */
  _constructIndex: function(node) {
    var index = '';
    do {
      if (node.id) index = '[' + node.position + ']' + index;
    } while ((node = node.parent) != null);
    return index;
  },

  sequence: function(element) {
    element = $(element);
    var options = Object.extend(this.options(element), arguments[1] || { });
    
    return $(this.findElements(element, options) || []).map( function(item) {
      return item.id.match(options.format) ? item.id.match(options.format)[1] : '';
    });
  },

  setSequence: function(element, new_sequence) {
    element = $(element);
    var options = Object.extend(this.options(element), arguments[2] || { });
    
    var nodeMap = { };
    this.findElements(element, options).each( function(n) {
        if (n.id.match(options.format))
            nodeMap[n.id.match(options.format)[1]] = [n, n.parentNode];
        n.parentNode.removeChild(n);
    });
   
    new_sequence.each(function(ident) {
      var n = nodeMap[ident];
      if (n) {
        n[1].appendChild(n[0]);
        delete nodeMap[ident];
      }
    });
  },
  
  serialize: function(element) {
    element = $(element);
    var options = Object.extend(Sortable.options(element), arguments[1] || { });
    var name = encodeURIComponent(
      (arguments[1] && arguments[1].name) ? arguments[1].name : element.id);
    
    if (options.tree) {
      return Sortable.tree(element, arguments[1]).children.map( function (item) {
        return [name + Sortable._constructIndex(item) + "[id]=" + 
                encodeURIComponent(item.id)].concat(item.children.map(arguments.callee));
      }).flatten().join('&');
    } else {
      return Sortable.sequence(element, arguments[1]).map( function(item) {
        return name + "[]=" + encodeURIComponent(item);
      }).join('&');
    }
  }
}

// Returns true if child is contained within element
Element.isParent = function(child, element) {
  if (!child.parentNode || child == element) return false;
  if (child.parentNode == element) return true;
  return Element.isParent(child.parentNode, element);
}

Element.findChildren = function(element, only, recursive, tagName) {   
  if(!element.hasChildNodes()) return null;
  tagName = tagName.toUpperCase();
  if(only) only = [only].flatten();
  var elements = [];
  $A(element.childNodes).each( function(e) {
    if(e.tagName && e.tagName.toUpperCase()==tagName &&
      (!only || (Element.classNames(e).detect(function(v) { return only.include(v) }))))
        elements.push(e);
    if(recursive) {
      var grandchildren = Element.findChildren(e, only, recursive, tagName);
      if(grandchildren) elements.push(grandchildren);
    }
  });

  return (elements.length>0 ? elements.flatten() : []);
}

Element.offsetSize = function (element, type) {
  return element['offset' + ((type=='vertical' || type=='height') ? 'Height' : 'Width')];
}


// Copyright (c) 2005-2008 Thomas Fuchs (http://script.aculo.us, http://mir.aculo.us)
//           (c) 2005-2007 Ivan Krstic (http://blogs.law.harvard.edu/ivan)
//           (c) 2005-2007 Jon Tirsen (http://www.tirsen.com)
// Contributors:
//  Richard Livsey
//  Rahul Bhargava
//  Rob Wills
// 
// script.aculo.us is freely distributable under the terms of an MIT-style license.
// For details, see the script.aculo.us web site: http://script.aculo.us/

// Autocompleter.Base handles all the autocompletion functionality 
// that's independent of the data source for autocompletion. This
// includes drawing the autocompletion menu, observing keyboard
// and mouse events, and similar.
//
// Specific autocompleters need to provide, at the very least, 
// a getUpdatedChoices function that will be invoked every time
// the text inside the monitored textbox changes. This method 
// should get the text for which to provide autocompletion by
// invoking this.getToken(), NOT by directly accessing
// this.element.value. This is to allow incremental tokenized
// autocompletion. Specific auto-completion logic (AJAX, etc)
// belongs in getUpdatedChoices.
//
// Tokenized incremental autocompletion is enabled automatically
// when an autocompleter is instantiated with the 'tokens' option
// in the options parameter, e.g.:
// new Ajax.Autocompleter('id','upd', '/url/', { tokens: ',' });
// will incrementally autocomplete with a comma as the token.
// Additionally, ',' in the above example can be replaced with
// a token array, e.g. { tokens: [',', '\n'] } which
// enables autocompletion on multiple tokens. This is most 
// useful when one of the tokens is \n (a newline), as it 
// allows smart autocompletion after linebreaks.

if(typeof Effect == 'undefined')
  throw("controls.js requires including script.aculo.us' effects.js library");

var Autocompleter = { }
Autocompleter.Base = Class.create({
  baseInitialize: function(element, update, options) {
    element          = $(element)
    this.element     = element; 
    this.update      = $(update);  
    this.hasFocus    = false; 
    this.changed     = false; 
    this.active      = false; 
    this.index       = 0;     
    this.entryCount  = 0;
    this.oldElementValue = this.element.value;

    if(this.setOptions)
      this.setOptions(options);
    else
      this.options = options || { };

    this.options.paramName    = this.options.paramName || this.element.name;
    this.options.tokens       = this.options.tokens || [];
    this.options.frequency    = this.options.frequency || 0.4;
    this.options.minChars     = this.options.minChars || 1;
    this.options.onShow       = this.options.onShow || 
      function(element, update){ 
        if(!update.style.position || update.style.position=='absolute') {
          update.style.position = 'absolute';
          Position.clone(element, update, {
            setHeight: false, 
            offsetTop: element.offsetHeight
          });
        }
        Effect.Appear(update,{duration:0.15});
      };
    this.options.onHide = this.options.onHide || 
      function(element, update){ new Effect.Fade(update,{duration:0.15}) };

    if(typeof(this.options.tokens) == 'string') 
      this.options.tokens = new Array(this.options.tokens);
    // Force carriage returns as token delimiters anyway
    if (!this.options.tokens.include('\n'))
      this.options.tokens.push('\n');

    this.observer = null;
    
    this.element.setAttribute('autocomplete','off');

    Element.hide(this.update);

    Event.observe(this.element, 'blur', this.onBlur.bindAsEventListener(this));
    Event.observe(this.element, 'keydown', this.onKeyPress.bindAsEventListener(this));
  },

  show: function() {
    if(Element.getStyle(this.update, 'display')=='none') this.options.onShow(this.element, this.update);
    if(!this.iefix && 
      (Prototype.Browser.IE) &&
      (Element.getStyle(this.update, 'position')=='absolute')) {
      new Insertion.After(this.update, 
       '<iframe id="' + this.update.id + '_iefix" '+
       'style="display:none;position:absolute;filter:progid:DXImageTransform.Microsoft.Alpha(opacity=0);" ' +
       'src="javascript:false;" frameborder="0" scrolling="no"></iframe>');
      this.iefix = $(this.update.id+'_iefix');
    }
    if(this.iefix) setTimeout(this.fixIEOverlapping.bind(this), 50);
  },
  
  fixIEOverlapping: function() {
    Position.clone(this.update, this.iefix, {setTop:(!this.update.style.height)});
    this.iefix.style.zIndex = 1;
    this.update.style.zIndex = 2;
    Element.show(this.iefix);
  },

  hide: function() {
    this.stopIndicator();
    if(Element.getStyle(this.update, 'display')!='none') this.options.onHide(this.element, this.update);
    if(this.iefix) Element.hide(this.iefix);
  },

  startIndicator: function() {
    if(this.options.indicator) Element.show(this.options.indicator);
  },

  stopIndicator: function() {
    if(this.options.indicator) Element.hide(this.options.indicator);
  },

  onKeyPress: function(event) {
    if(this.active)
      switch(event.keyCode) {
       case Event.KEY_TAB:
       case Event.KEY_RETURN:
         this.selectEntry();
         Event.stop(event);
       case Event.KEY_ESC:
         this.hide();
         this.active = false;
         Event.stop(event);
         return;
       case Event.KEY_LEFT:
       case Event.KEY_RIGHT:
         return;
       case Event.KEY_UP:
         this.markPrevious();
         this.render();
         Event.stop(event);
         return;
       case Event.KEY_DOWN:
         this.markNext();
         this.render();
         Event.stop(event);
         return;
      }
     else 
       if(event.keyCode==Event.KEY_TAB || event.keyCode==Event.KEY_RETURN || 
         (Prototype.Browser.WebKit > 0 && event.keyCode == 0)) return;

    this.changed = true;
    this.hasFocus = true;

    if(this.observer) clearTimeout(this.observer);
      this.observer = 
        setTimeout(this.onObserverEvent.bind(this), this.options.frequency*1000);
  },

  activate: function() {
    this.changed = false;
    this.hasFocus = true;
    this.getUpdatedChoices();
  },

  onHover: function(event) {
    var element = Event.findElement(event, 'LI');
    if(this.index != element.autocompleteIndex) 
    {
        this.index = element.autocompleteIndex;
        this.render();
    }
    Event.stop(event);
  },
  
  onClick: function(event) {
    var element = Event.findElement(event, 'LI');
    this.index = element.autocompleteIndex;
    this.selectEntry();
    this.hide();
  },
  
  onBlur: function(event) {
    // needed to make click events working
    setTimeout(this.hide.bind(this), 250);
    this.hasFocus = false;
    this.active = false;     
  }, 
  
  render: function() {
    if(this.entryCount > 0) {
      for (var i = 0; i < this.entryCount; i++)
        this.index==i ? 
          Element.addClassName(this.getEntry(i),"selected") : 
          Element.removeClassName(this.getEntry(i),"selected");
      if(this.hasFocus) { 
        this.show();
        this.active = true;
      }
    } else {
      this.active = false;
      this.hide();
    }
  },
  
  markPrevious: function() {
    if(this.index > 0) this.index--
      else this.index = this.entryCount-1;
    this.getEntry(this.index).scrollIntoView(true);
  },
  
  markNext: function() {
    if(this.index < this.entryCount-1) this.index++
      else this.index = 0;
    this.getEntry(this.index).scrollIntoView(false);
  },
  
  getEntry: function(index) {
    return this.update.firstChild.childNodes[index];
  },
  
  getCurrentEntry: function() {
    return this.getEntry(this.index);
  },
  
  selectEntry: function() {
    this.active = false;
    this.updateElement(this.getCurrentEntry());
  },

  updateElement: function(selectedElement) {
    if (this.options.updateElement) {
      this.options.updateElement(selectedElement);
      return;
    }
    var value = '';
    if (this.options.select) {
      var nodes = $(selectedElement).select('.' + this.options.select) || [];
      if(nodes.length>0) value = Element.collectTextNodes(nodes[0], this.options.select);
    } else
      value = Element.collectTextNodesIgnoreClass(selectedElement, 'informal');
    
    var bounds = this.getTokenBounds();
    if (bounds[0] != -1) {
      var newValue = this.element.value.substr(0, bounds[0]);
      var whitespace = this.element.value.substr(bounds[0]).match(/^\s+/);
      if (whitespace)
        newValue += whitespace[0];
      this.element.value = newValue + value + this.element.value.substr(bounds[1]);
    } else {
      this.element.value = value;
    }
    this.oldElementValue = this.element.value;
    this.element.focus();
    
    if (this.options.afterUpdateElement)
      this.options.afterUpdateElement(this.element, selectedElement);
  },

  updateChoices: function(choices) {
    if(!this.changed && this.hasFocus) {
      this.update.innerHTML = choices;
      Element.cleanWhitespace(this.update);
      Element.cleanWhitespace(this.update.down());

      if(this.update.firstChild && this.update.down().childNodes) {
        this.entryCount = 
          this.update.down().childNodes.length;
        for (var i = 0; i < this.entryCount; i++) {
          var entry = this.getEntry(i);
          entry.autocompleteIndex = i;
          this.addObservers(entry);
        }
      } else { 
        this.entryCount = 0;
      }

      this.stopIndicator();
      this.index = 0;
      
      if(this.entryCount==1 && this.options.autoSelect) {
        this.selectEntry();
        this.hide();
      } else {
        this.render();
      }
    }
  },

  addObservers: function(element) {
    Event.observe(element, "mouseover", this.onHover.bindAsEventListener(this));
    Event.observe(element, "click", this.onClick.bindAsEventListener(this));
  },

  onObserverEvent: function() {
    this.changed = false;   
    this.tokenBounds = null;
    if(this.getToken().length>=this.options.minChars) {
      this.getUpdatedChoices();
    } else {
      this.active = false;
      this.hide();
    }
    this.oldElementValue = this.element.value;
  },

  getToken: function() {
    var bounds = this.getTokenBounds();
    return this.element.value.substring(bounds[0], bounds[1]).strip();
  },

  getTokenBounds: function() {
    if (null != this.tokenBounds) return this.tokenBounds;
    var value = this.element.value;
    if (value.strip().empty()) return [-1, 0];
    var diff = arguments.callee.getFirstDifferencePos(value, this.oldElementValue);
    var offset = (diff == this.oldElementValue.length ? 1 : 0);
    var prevTokenPos = -1, nextTokenPos = value.length;
    var tp;
    for (var index = 0, l = this.options.tokens.length; index < l; ++index) {
      tp = value.lastIndexOf(this.options.tokens[index], diff + offset - 1);
      if (tp > prevTokenPos) prevTokenPos = tp;
      tp = value.indexOf(this.options.tokens[index], diff + offset);
      if (-1 != tp && tp < nextTokenPos) nextTokenPos = tp;
    }
    return (this.tokenBounds = [prevTokenPos + 1, nextTokenPos]);
  }
});

Autocompleter.Base.prototype.getTokenBounds.getFirstDifferencePos = function(newS, oldS) {
  var boundary = Math.min(newS.length, oldS.length);
  for (var index = 0; index < boundary; ++index)
    if (newS[index] != oldS[index])
      return index;
  return boundary;
};

Ajax.Autocompleter = Class.create(Autocompleter.Base, {
  initialize: function(element, update, url, options) {
    this.baseInitialize(element, update, options);
    this.options.asynchronous  = true;
    this.options.onComplete    = this.onComplete.bind(this);
    this.options.defaultParams = this.options.parameters || null;
    this.url                   = url;
  },

  getUpdatedChoices: function() {
    this.startIndicator();
    
    var entry = encodeURIComponent(this.options.paramName) + '=' + 
      encodeURIComponent(this.getToken());

    this.options.parameters = this.options.callback ?
      this.options.callback(this.element, entry) : entry;

    if(this.options.defaultParams) 
      this.options.parameters += '&' + this.options.defaultParams;
    
    new Ajax.Request(this.url, this.options);
  },

  onComplete: function(request) {
    this.updateChoices(request.responseText);
  }
});

// The local array autocompleter. Used when you'd prefer to
// inject an array of autocompletion options into the page, rather
// than sending out Ajax queries, which can be quite slow sometimes.
//
// The constructor takes four parameters. The first two are, as usual,
// the id of the monitored textbox, and id of the autocompletion menu.
// The third is the array you want to autocomplete from, and the fourth
// is the options block.
//
// Extra local autocompletion options:
// - choices - How many autocompletion choices to offer
//
// - partialSearch - If false, the autocompleter will match entered
//                    text only at the beginning of strings in the 
//                    autocomplete array. Defaults to true, which will
//                    match text at the beginning of any *word* in the
//                    strings in the autocomplete array. If you want to
//                    search anywhere in the string, additionally set
//                    the option fullSearch to true (default: off).
//
// - fullSsearch - Search anywhere in autocomplete array strings.
//
// - partialChars - How many characters to enter before triggering
//                   a partial match (unlike minChars, which defines
//                   how many characters are required to do any match
//                   at all). Defaults to 2.
//
// - ignoreCase - Whether to ignore case when autocompleting.
//                 Defaults to true.
//
// It's possible to pass in a custom function as the 'selector' 
// option, if you prefer to write your own autocompletion logic.
// In that case, the other options above will not apply unless
// you support them.

Autocompleter.Local = Class.create(Autocompleter.Base, {
  initialize: function(element, update, array, options) {
    this.baseInitialize(element, update, options);
    this.options.array = array;
  },

  getUpdatedChoices: function() {
    this.updateChoices(this.options.selector(this));
  },

  setOptions: function(options) {
    this.options = Object.extend({
      choices: 10,
      partialSearch: true,
      partialChars: 2,
      ignoreCase: true,
      fullSearch: false,
      selector: function(instance) {
        var ret       = []; // Beginning matches
        var partial   = []; // Inside matches
        var entry     = instance.getToken();
        var count     = 0;

        for (var i = 0; i < instance.options.array.length &&  
          ret.length < instance.options.choices ; i++) { 

          var elem = instance.options.array[i];
          var foundPos = instance.options.ignoreCase ? 
            elem.toLowerCase().indexOf(entry.toLowerCase()) : 
            elem.indexOf(entry);

          while (foundPos != -1) {
            if (foundPos == 0 && elem.length != entry.length) { 
              ret.push("<li><strong>" + elem.substr(0, entry.length) + "</strong>" + 
                elem.substr(entry.length) + "</li>");
              break;
            } else if (entry.length >= instance.options.partialChars && 
              instance.options.partialSearch && foundPos != -1) {
              if (instance.options.fullSearch || /\s/.test(elem.substr(foundPos-1,1))) {
                partial.push("<li>" + elem.substr(0, foundPos) + "<strong>" +
                  elem.substr(foundPos, entry.length) + "</strong>" + elem.substr(
                  foundPos + entry.length) + "</li>");
                break;
              }
            }

            foundPos = instance.options.ignoreCase ? 
              elem.toLowerCase().indexOf(entry.toLowerCase(), foundPos + 1) : 
              elem.indexOf(entry, foundPos + 1);

          }
        }
        if (partial.length)
          ret = ret.concat(partial.slice(0, instance.options.choices - ret.length))
        return "<ul>" + ret.join('') + "</ul>";
      }
    }, options || { });
  }
});

// AJAX in-place editor and collection editor
// Full rewrite by Christophe Porteneuve <tdd@tddsworld.com> (April 2007).

// Use this if you notice weird scrolling problems on some browsers,
// the DOM might be a bit confused when this gets called so do this
// waits 1 ms (with setTimeout) until it does the activation
Field.scrollFreeActivate = function(field) {
  setTimeout(function() {
    Field.activate(field);
  }, 1);
}

Ajax.InPlaceEditor = Class.create({
  initialize: function(element, url, options) {
    this.url = url;
    this.element = element = $(element);
    this.prepareOptions();
    this._controls = { };
    arguments.callee.dealWithDeprecatedOptions(options); // DEPRECATION LAYER!!!
    Object.extend(this.options, options || { });
    if (!this.options.formId && this.element.id) {
      this.options.formId = this.element.id + '-inplaceeditor';
      if ($(this.options.formId))
        this.options.formId = '';
    }
    if (this.options.externalControl)
      this.options.externalControl = $(this.options.externalControl);
    if (!this.options.externalControl)
      this.options.externalControlOnly = false;
    this._originalBackground = this.element.getStyle('background-color') || 'transparent';
    this.element.title = this.options.clickToEditText;
    this._boundCancelHandler = this.handleFormCancellation.bind(this);
    this._boundComplete = (this.options.onComplete || Prototype.emptyFunction).bind(this);
    this._boundFailureHandler = this.handleAJAXFailure.bind(this);
    this._boundSubmitHandler = this.handleFormSubmission.bind(this);
    this._boundWrapperHandler = this.wrapUp.bind(this);
    this.registerListeners();
  },
  checkForEscapeOrReturn: function(e) {
    if (!this._editing || e.ctrlKey || e.altKey || e.shiftKey) return;
    if (Event.KEY_ESC == e.keyCode)
      this.handleFormCancellation(e);
    else if (Event.KEY_RETURN == e.keyCode)
      this.handleFormSubmission(e);
  },
  createControl: function(mode, handler, extraClasses) {
    var control = this.options[mode + 'Control'];
    var text = this.options[mode + 'Text'];
    if ('button' == control) {
      var btn = document.createElement('input');
      btn.type = 'submit';
      btn.value = text;
      btn.className = 'editor_' + mode + '_button';
      if ('cancel' == mode)
        btn.onclick = this._boundCancelHandler;
      this._form.appendChild(btn);
      this._controls[mode] = btn;
    } else if ('link' == control) {
      var link = document.createElement('a');
      link.href = '#';
      link.appendChild(document.createTextNode(text));
      link.onclick = 'cancel' == mode ? this._boundCancelHandler : this._boundSubmitHandler;
      link.className = 'editor_' + mode + '_link';
      if (extraClasses)
        link.className += ' ' + extraClasses;
      this._form.appendChild(link);
      this._controls[mode] = link;
    }
  },
  createEditField: function() {
    var text = (this.options.loadTextURL ? this.options.loadingText : this.getText());
    var fld;
    if (1 >= this.options.rows && !/\r|\n/.test(this.getText())) {
      fld = document.createElement('input');
      fld.type = 'text';
      var size = this.options.size || this.options.cols || 0;
      if (0 < size) fld.size = size;
    } else {
      fld = document.createElement('textarea');
      fld.rows = (1 >= this.options.rows ? this.options.autoRows : this.options.rows);
      fld.cols = this.options.cols || 40;
    }
    fld.name = this.options.paramName;
    fld.value = text; // No HTML breaks conversion anymore
    fld.className = 'editor_field';
    if (this.options.submitOnBlur)
      fld.onblur = this._boundSubmitHandler;
    this._controls.editor = fld;
    if (this.options.loadTextURL)
      this.loadExternalText();
    this._form.appendChild(this._controls.editor);
  },
  createForm: function() {
    var ipe = this;
    function addText(mode, condition) {
      var text = ipe.options['text' + mode + 'Controls'];
      if (!text || condition === false) return;
      ipe._form.appendChild(document.createTextNode(text));
    };
    this._form = $(document.createElement('form'));
    this._form.id = this.options.formId;
    this._form.addClassName(this.options.formClassName);
    this._form.onsubmit = this._boundSubmitHandler;
    this.createEditField();
    if ('textarea' == this._controls.editor.tagName.toLowerCase())
      this._form.appendChild(document.createElement('br'));
    if (this.options.onFormCustomization)
      this.options.onFormCustomization(this, this._form);
    addText('Before', this.options.okControl || this.options.cancelControl);
    this.createControl('ok', this._boundSubmitHandler);
    addText('Between', this.options.okControl && this.options.cancelControl);
    this.createControl('cancel', this._boundCancelHandler, 'editor_cancel');
    addText('After', this.options.okControl || this.options.cancelControl);
  },
  destroy: function() {
    if (this._oldInnerHTML)
      this.element.innerHTML = this._oldInnerHTML;
    this.leaveEditMode();
    this.unregisterListeners();
  },
  enterEditMode: function(e) {
    if (this._saving || this._editing) return;
    this._editing = true;
    this.triggerCallback('onEnterEditMode');
    if (this.options.externalControl)
      this.options.externalControl.hide();
    this.element.hide();
    this.createForm();
    this.element.parentNode.insertBefore(this._form, this.element);
    if (!this.options.loadTextURL)
      this.postProcessEditField();
    if (e) Event.stop(e);
  },
  enterHover: function(e) {
    if (this.options.hoverClassName)
      this.element.addClassName(this.options.hoverClassName);
    if (this._saving) return;
    this.triggerCallback('onEnterHover');
  },
  getText: function() {
    return this.element.innerHTML;
  },
  handleAJAXFailure: function(transport) {
    this.triggerCallback('onFailure', transport);
    if (this._oldInnerHTML) {
      this.element.innerHTML = this._oldInnerHTML;
      this._oldInnerHTML = null;
    }
  },
  handleFormCancellation: function(e) {
    this.wrapUp();
    if (e) Event.stop(e);
  },
  handleFormSubmission: function(e) {
    var form = this._form;
    var value = $F(this._controls.editor);
    this.prepareSubmission();
    var params = this.options.callback(form, value) || '';
    if (Object.isString(params))
      params = params.toQueryParams();
    params.editorId = this.element.id;
    if (this.options.htmlResponse) {
      var options = Object.extend({ evalScripts: true }, this.options.ajaxOptions);
      Object.extend(options, {
        parameters: params,
        onComplete: this._boundWrapperHandler,
        onFailure: this._boundFailureHandler
      });
      new Ajax.Updater({ success: this.element }, this.url, options);
    } else {
      var options = Object.extend({ method: 'get' }, this.options.ajaxOptions);
      Object.extend(options, {
        parameters: params,
        onComplete: this._boundWrapperHandler,
        onFailure: this._boundFailureHandler
      });
      new Ajax.Request(this.url, options);
    }
    if (e) Event.stop(e);
  },
  leaveEditMode: function() {
    this.element.removeClassName(this.options.savingClassName);
    this.removeForm();
    this.leaveHover();
    this.element.style.backgroundColor = this._originalBackground;
    this.element.show();
    if (this.options.externalControl)
      this.options.externalControl.show();
    this._saving = false;
    this._editing = false;
    this._oldInnerHTML = null;
    this.triggerCallback('onLeaveEditMode');
  },
  leaveHover: function(e) {
    if (this.options.hoverClassName)
      this.element.removeClassName(this.options.hoverClassName);
    if (this._saving) return;
    this.triggerCallback('onLeaveHover');
  },
  loadExternalText: function() {
    this._form.addClassName(this.options.loadingClassName);
    this._controls.editor.disabled = true;
    var options = Object.extend({ method: 'get' }, this.options.ajaxOptions);
    Object.extend(options, {
      parameters: 'editorId=' + encodeURIComponent(this.element.id),
      onComplete: Prototype.emptyFunction,
      onSuccess: function(transport) {
        this._form.removeClassName(this.options.loadingClassName);
        var text = transport.responseText;
        if (this.options.stripLoadedTextTags)
          text = text.stripTags();
        this._controls.editor.value = text;
        this._controls.editor.disabled = false;
        this.postProcessEditField();
      }.bind(this),
      onFailure: this._boundFailureHandler
    });
    new Ajax.Request(this.options.loadTextURL, options);
  },
  postProcessEditField: function() {
    var fpc = this.options.fieldPostCreation;
    if (fpc)
      $(this._controls.editor)['focus' == fpc ? 'focus' : 'activate']();
  },
  prepareOptions: function() {
    this.options = Object.clone(Ajax.InPlaceEditor.DefaultOptions);
    Object.extend(this.options, Ajax.InPlaceEditor.DefaultCallbacks);
    [this._extraDefaultOptions].flatten().compact().each(function(defs) {
      Object.extend(this.options, defs);
    }.bind(this));
  },
  prepareSubmission: function() {
    this._saving = true;
    this.removeForm();
    this.leaveHover();
    this.showSaving();
  },
  registerListeners: function() {
    this._listeners = { };
    var listener;
    $H(Ajax.InPlaceEditor.Listeners).each(function(pair) {
      listener = this[pair.value].bind(this);
      this._listeners[pair.key] = listener;
      if (!this.options.externalControlOnly)
        this.element.observe(pair.key, listener);
      if (this.options.externalControl)
        this.options.externalControl.observe(pair.key, listener);
    }.bind(this));
  },
  removeForm: function() {
    if (!this._form) return;
    this._form.remove();
    this._form = null;
    this._controls = { };
  },
  showSaving: function() {
    this._oldInnerHTML = this.element.innerHTML;
    this.element.innerHTML = this.options.savingText;
    this.element.addClassName(this.options.savingClassName);
    this.element.style.backgroundColor = this._originalBackground;
    this.element.show();
  },
  triggerCallback: function(cbName, arg) {
    if ('function' == typeof this.options[cbName]) {
      this.options[cbName](this, arg);
    }
  },
  unregisterListeners: function() {
    $H(this._listeners).each(function(pair) {
      if (!this.options.externalControlOnly)
        this.element.stopObserving(pair.key, pair.value);
      if (this.options.externalControl)
        this.options.externalControl.stopObserving(pair.key, pair.value);
    }.bind(this));
  },
  wrapUp: function(transport) {
    this.leaveEditMode();
    // Can't use triggerCallback due to backward compatibility: requires
    // binding + direct element
    this._boundComplete(transport, this.element);
  }
});

Object.extend(Ajax.InPlaceEditor.prototype, {
  dispose: Ajax.InPlaceEditor.prototype.destroy
});

Ajax.InPlaceCollectionEditor = Class.create(Ajax.InPlaceEditor, {
  initialize: function($super, element, url, options) {
    this._extraDefaultOptions = Ajax.InPlaceCollectionEditor.DefaultOptions;
    $super(element, url, options);
  },

  createEditField: function() {
    var list = document.createElement('select');
    list.name = this.options.paramName;
    list.size = 1;
    this._controls.editor = list;
    this._collection = this.options.collection || [];
    if (this.options.loadCollectionURL)
      this.loadCollection();
    else
      this.checkForExternalText();
    this._form.appendChild(this._controls.editor);
  },

  loadCollection: function() {
    this._form.addClassName(this.options.loadingClassName);
    this.showLoadingText(this.options.loadingCollectionText);
    var options = Object.extend({ method: 'get' }, this.options.ajaxOptions);
    Object.extend(options, {
      parameters: 'editorId=' + encodeURIComponent(this.element.id),
      onComplete: Prototype.emptyFunction,
      onSuccess: function(transport) {
        var js = transport.responseText.strip();
        if (!/^\[.*\]$/.test(js)) // TODO: improve sanity check
          throw 'Server returned an invalid collection representation.';
        this._collection = eval(js);
        this.checkForExternalText();
      }.bind(this),
      onFailure: this.onFailure
    });
    new Ajax.Request(this.options.loadCollectionURL, options);
  },

  showLoadingText: function(text) {
    this._controls.editor.disabled = true;
    var tempOption = this._controls.editor.firstChild;
    if (!tempOption) {
      tempOption = document.createElement('option');
      tempOption.value = '';
      this._controls.editor.appendChild(tempOption);
      tempOption.selected = true;
    }
    tempOption.update((text || '').stripScripts().stripTags());
  },

  checkForExternalText: function() {
    this._text = this.getText();
    if (this.options.loadTextURL)
      this.loadExternalText();
    else
      this.buildOptionList();
  },

  loadExternalText: function() {
    this.showLoadingText(this.options.loadingText);
    var options = Object.extend({ method: 'get' }, this.options.ajaxOptions);
    Object.extend(options, {
      parameters: 'editorId=' + encodeURIComponent(this.element.id),
      onComplete: Prototype.emptyFunction,
      onSuccess: function(transport) {
        this._text = transport.responseText.strip();
        this.buildOptionList();
      }.bind(this),
      onFailure: this.onFailure
    });
    new Ajax.Request(this.options.loadTextURL, options);
  },

  buildOptionList: function() {
    this._form.removeClassName(this.options.loadingClassName);
    this._collection = this._collection.map(function(entry) {
      return 2 === entry.length ? entry : [entry, entry].flatten();
    });
    var marker = ('value' in this.options) ? this.options.value : this._text;
    var textFound = this._collection.any(function(entry) {
      return entry[0] == marker;
    }.bind(this));
    this._controls.editor.update('');
    var option;
    this._collection.each(function(entry, index) {
      option = document.createElement('option');
      option.value = entry[0];
      option.selected = textFound ? entry[0] == marker : 0 == index;
      option.appendChild(document.createTextNode(entry[1]));
      this._controls.editor.appendChild(option);
    }.bind(this));
    this._controls.editor.disabled = false;
    Field.scrollFreeActivate(this._controls.editor);
  }
});

//**** DEPRECATION LAYER FOR InPlace[Collection]Editor! ****
//**** This only  exists for a while,  in order to  let ****
//**** users adapt to  the new API.  Read up on the new ****
//**** API and convert your code to it ASAP!            ****

Ajax.InPlaceEditor.prototype.initialize.dealWithDeprecatedOptions = function(options) {
  if (!options) return;
  function fallback(name, expr) {
    if (name in options || expr === undefined) return;
    options[name] = expr;
  };
  fallback('cancelControl', (options.cancelLink ? 'link' : (options.cancelButton ? 'button' :
    options.cancelLink == options.cancelButton == false ? false : undefined)));
  fallback('okControl', (options.okLink ? 'link' : (options.okButton ? 'button' :
    options.okLink == options.okButton == false ? false : undefined)));
  fallback('highlightColor', options.highlightcolor);
  fallback('highlightEndColor', options.highlightendcolor);
};

Object.extend(Ajax.InPlaceEditor, {
  DefaultOptions: {
    ajaxOptions: { },
    autoRows: 3,                                // Use when multi-line w/ rows == 1
    cancelControl: 'link',                      // 'link'|'button'|false
    cancelText: 'cancel',
    clickToEditText: 'Click to edit',
    externalControl: null,                      // id|elt
    externalControlOnly: false,
    fieldPostCreation: 'activate',              // 'activate'|'focus'|false
    formClassName: 'inplaceeditor-form',
    formId: null,                               // id|elt
    highlightColor: '#ffff99',
    highlightEndColor: '#ffffff',
    hoverClassName: '',
    htmlResponse: true,
    loadingClassName: 'inplaceeditor-loading',
    loadingText: 'Loading...',
    okControl: 'button',                        // 'link'|'button'|false
    okText: 'ok',
    paramName: 'value',
    rows: 1,                                    // If 1 and multi-line, uses autoRows
    savingClassName: 'inplaceeditor-saving',
    savingText: 'Saving...',
    size: 0,
    stripLoadedTextTags: false,
    submitOnBlur: false,
    textAfterControls: '',
    textBeforeControls: '',
    textBetweenControls: ''
  },
  DefaultCallbacks: {
    callback: function(form) {
      return Form.serialize(form);
    },
    onComplete: function(transport, element) {
      // For backward compatibility, this one is bound to the IPE, and passes
      // the element directly.  It was too often customized, so we don't break it.
      new Effect.Highlight(element, {
        startcolor: this.options.highlightColor, keepBackgroundImage: true });
    },
    onEnterEditMode: null,
    onEnterHover: function(ipe) {
      ipe.element.style.backgroundColor = ipe.options.highlightColor;
      if (ipe._effect)
        ipe._effect.cancel();
    },
    onFailure: function(transport, ipe) {
      alert('Error communication with the server: ' + transport.responseText.stripTags());
    },
    onFormCustomization: null, // Takes the IPE and its generated form, after editor, before controls.
    onLeaveEditMode: null,
    onLeaveHover: function(ipe) {
      ipe._effect = new Effect.Highlight(ipe.element, {
        startcolor: ipe.options.highlightColor, endcolor: ipe.options.highlightEndColor,
        restorecolor: ipe._originalBackground, keepBackgroundImage: true
      });
    }
  },
  Listeners: {
    click: 'enterEditMode',
    keydown: 'checkForEscapeOrReturn',
    mouseover: 'enterHover',
    mouseout: 'leaveHover'
  }
});

Ajax.InPlaceCollectionEditor.DefaultOptions = {
  loadingCollectionText: 'Loading options...'
};

// Delayed observer, like Form.Element.Observer, 
// but waits for delay after last key input
// Ideal for live-search fields

Form.Element.DelayedObserver = Class.create({
  initialize: function(element, delay, callback) {
    this.delay     = delay || 0.5;
    this.element   = $(element);
    this.callback  = callback;
    this.timer     = null;
    this.lastValue = $F(this.element); 
    Event.observe(this.element,'keyup',this.delayedListener.bindAsEventListener(this));
  },
  delayedListener: function(event) {
    if(this.lastValue == $F(this.element)) return;
    if(this.timer) clearTimeout(this.timer);
    this.timer = setTimeout(this.onTimerEvent.bind(this), this.delay * 1000);
    this.lastValue = $F(this.element);
  },
  onTimerEvent: function() {
    this.timer = null;
    this.callback(this.element, $F(this.element));
  }
});


/*
 * Creating and deleting IMG nodes seems to cause memory leaks in WebKit, but
 * there are also reports that keeping the same node and replacing src can cause
 * memory leaks (also in WebKit).
 *
 * So we don't have to depend on doing one or the other in other code, abstract
 * this.  Use ImgPool.get() and ImgPool.release() to retrieve a new IMG node and
 * return it.  We can choose here to either keep a pool, to avoid constantly
 * creating new ones, or to throw them away and create new ones, to avoid changing
 * src.
 *
 * This doesn't clear styles or any other properties.  To avoid leaking things from
 * one type of image to another, use separate pools for each.
 */

var ImgPoolHandlerWebKit = Class.create({
  initialize: function()
  {
    this.pool = [];
    this.pool_waiting = [];
    this.blank_image_loaded_event = this.blank_image_loaded_event.bind(this);
  },

  get: function()
  {
    if(this.pool.length == 0)
    {
      // debug("No images in pool; creating blank");
      return $(document.createElement("IMG"));
    }

    // debug("Returning image from pool");
    return this.pool.pop();
  },

  release: function(img)
  {
    /*
     * Replace the image with a blank, so when it's reused it doesn't show the previously-
     * loaded image until the new one is available.  Don't reuse the image until the blank
     * image is loaded.
     *
     * This also encourages the browser to abort any running download, so if we have a large
     * PNG downloading that we've cancelled it won't continue and download the whole thing.
     * Note that Firefox will stop a download if we do this, but not if we only remove an
     * image from the document.
     */
    img.observe("load", this.blank_image_loaded_event);
    this.pool_waiting.push(img);
    img.src = "/images/blank.png";
  },

  blank_image_loaded_event: function(event)
  {
    var img = event.target;
    img.stopObserving("load", this.blank_image_loaded_event);
    this.pool_waiting = this.pool_waiting.without(img);
    this.pool.push(img);
  }
});

var ImgPoolHandlerDummy = Class.create({
  get: function()
  {
    return $(document.createElement("IMG"));
  },

  release: function(img)
  {
    img.src = "/images/blank.png";
  }
});

/* Create an image pool handler.  If the URL hash value "image-pools" is specified,
 * force image pools on or off for debugging; otherwise enable them only when needed. */
var ImgPoolHandler = function()
{
  var use_image_pools = Prototype.Browser.WebKit;
  var hash_value = UrlHash.get("image-pools");
  if(hash_value != null)
    use_image_pools = (hash_value != "0");

  if(use_image_pools)
    return new ImgPoolHandlerWebKit(arguments);
  else
    return new ImgPoolHandlerDummy(arguments);
}



PostLoader = function()
{
  document.on("viewer:need-more-thumbs", this.need_more_post_data.bindAsEventListener(this));
  document.on("viewer:perform-search", this.perform_search.bindAsEventListener(this));

  this.hashchange_tags = this.hashchange_tags.bind(this);
  UrlHash.observe("tags", this.hashchange_tags);

  this.cached_posts = new Hash();
  this.cached_pools = new Hash();
  this.sample_preload_container = null;
  this.preloading_sample_for_post_id = null;

  this.load({results_mode: "center-on-current"});
}

PostLoader.prototype.need_more_post_data = function()
{
  /* We'll receive this message often once we're close to needing more posts.  Only
   * start loading more data the first time. */
  if(this.loaded_extended_results)
    return;

  this.load({extending: true});
}


/*
 * This is a response time optimization.  If we know the sample URL of what we want to display,
 * we can start loading it from the server without waiting for the full post/index.json response
 * to come back and tell us.  This saves us the time of a round-trip before we start loading the
 * image.  The common case is if the user was on post/index and clicked on a link with "use
 * post browser" enabled.  This allows us to start loading the image immediately, without waiting
 * for any other network activity.
 *
 * We only do this for the sample image, to get a head-start loading it.  This is safe because
 * the image URLs are immutable (or effectively so).  The rest of the post information isn't cached.
 */
PostLoader.prototype.preload_sample_image = function()
{
  var post_id = UrlHash.get("post-id");
  if(this.preloading_sample_for_post_id == post_id)
    return;
  this.preloading_sample_for_post_id = post_id;

  if(this.sample_preload_container)
  {
    this.sample_preload_container.destroy();
    this.sample_preload_container = null;
  }

  if(post_id == null)
    return;

  /* If this returns null, the browser doesn't support this. */
  var cached_sample_urls = Post.get_cached_sample_urls();
  if(cached_sample_urls == null)
    return;

  if(!(String(post_id) in cached_sample_urls))
    return;
  var sample_url = cached_sample_urls[String(post_id)];

  /* If we have an existing preload_container, just add to it and allow any other
   * preloads to continue. */
  debug("Advance preloading sample image for post " + post_id);
  this.sample_preload_container = new PreloadContainer();
  this.sample_preload_container.preload(sample_url);
}

PostLoader.prototype.server_load_pool = function()
{
  if(this.result.pool_id == null)
    return;

  if(!this.result.disable_cache)
  {
    var pool = this.cached_pools.get(this.result.pool_id);
    if(pool)
    {
      this.result.pool = pool;
      this.request_finished();
      return;
    }
  }

  new Ajax.Request("/pool/show.json", {
    parameters: { id: this.result.pool_id },
    method: "get",
    onCreate: function(resp) {
      this.current_ajax_requests.push(resp.request);
    }.bind(this),

    onComplete: function(resp) {
      this.current_ajax_requests = this.current_ajax_requests.without(resp.request);
      this.request_finished();
    }.bind(this),

    onSuccess: function(resp) {
      if(this.current_ajax_requests.indexOf(resp.request) == -1)
        return;

      this.result.pool = resp.responseJSON;
      this.cached_pools.set(this.result.pool_id, this.result.pool);
    }.bind(this)
  });
}

PostLoader.prototype.server_load_posts = function()
{
  var tags = this.result.tags;

  // Put holds:false at the beginning, so the search can override it.  Put limit: at
  // the end, so it can't.
  var search = "holds:false " + tags + " limit:" + this.result.post_limit;

  if(!this.result.disable_cache)
  {
    var results = this.cached_posts.get(search);
    if(results)
    {
      this.result.posts = results;

      /* Don't Post.register the results when serving out of cache.  They're already
       * registered, and the data in the post registry may be more current than the
       * cached search results. */
      this.request_finished();
      return;
    }
  }

  new Ajax.Request("/post/index.json", {
    parameters: {
      tags: search,
      api_version: 2,
      filter: 1,
      include_tags: 1,
      include_votes: 1,
      include_pools: 1
    },
    method: "get",

    onCreate: function(resp) {
      this.current_ajax_requests.push(resp.request);
    }.bind(this),

    onComplete: function(resp) {
      this.current_ajax_requests = this.current_ajax_requests.without(resp.request);
      this.request_finished();
    }.bind(this),

    onSuccess: function(resp) {
      if(this.current_ajax_requests.indexOf(resp.request) == -1)
        return;
    
      var resp = resp.responseJSON;
      this.result.posts = resp.posts;

      Post.register_resp(resp);

      this.cached_posts.set(search, this.result.posts);
    }.bind(this),

    onFailure: function(resp) {
      var error = "error " + resp.status;
      if(resp.responseJSON)
        error = resp.responseJSON.reason;

      notice("Error loading posts: " + error);
      this.result.error = true;
    }.bind(this)
  });
}

PostLoader.prototype.request_finished = function()
{
  if(this.current_ajax_requests.length)
    return;

  /* Event handlers for the events we fire below might make requests back to us.  Save and
   * clear this.result before firing the events, so that behaves properly. */
  var result = this.result;
  this.result = null;

  /* If server_load_posts hit an error, it already displayed it; stop. */
  if(result.error != null)
    return;

  /* If we have no search tags (result.tags == null, result.posts == null), then we're just
   * displaying a post with no search, eg. "/post/browse#12345".  We'll still fire off the
   * same code path to make the post display in the view. */
  var new_post_ids = [];
  if(result.posts != null)
  {
    for(var i = 0; i < result.posts.length; ++i)
      new_post_ids.push(result.posts[i].id);
  }

  document.fire("viewer:displayed-pool-changed", { pool: result.pool });
  document.fire("viewer:searched-tags-changed", { tags: result.tags });

  /* Tell the thumbnail viewer whether it should allow scrolling over the left side. */
  var can_be_extended_further = true;

  /* If we're reading from a pool, we requested a large block already. */
  if(result.pool)
    can_be_extended_further = false;

  /* If we're already extending, don't extend further. */
  if(result.load_options.extending)
    can_be_extended_further = false;

  /* If we received fewer results than we requested we're at the end of the results,
   * so don't waste time requesting more. */
  if(new_post_ids.length < result.post_limit)
  {
    debug("Received posts fewer than requested (" + new_post_ids.length + " < " + result.post_limit + "), clamping");
    can_be_extended_further = false;
  }

  /* Now that we have the result, update the URL hash.  Firing loaded-posts may change
   * the displayed post, causing the post ID in the URL hash to change, so use set_deferred
   * to help ensure these happen atomically. */
  UrlHash.set_deferred({tags: result.tags});

  document.fire("viewer:loaded-posts", {
    tags: result.tags, /* this will be null if no search was actually performed (eg. URL with a post-id and no tags) */
    post_ids: new_post_ids,
    pool: result.pool,
    extending: result.load_options.extending,
    can_be_extended_further: can_be_extended_further,
    load_options: result.load_options
  });
}

/* If extending is true, load a larger set of posts. */
PostLoader.prototype.load = function(load_options)
{
  if(!load_options)
    load_options = {}

  var disable_cache = load_options.disable_cache;
  var extending = load_options.extending;

  var tags = load_options.tags;
  if(tags == null)
    tags = UrlHash.get("tags");

  /* If neither a search nor a post-id is specified, set a default search. */
  if(!extending && tags == null && UrlHash.get("post-id") == null)
  {
    UrlHash.set({tags: ""});

    /* We'll receive another hashchange message for setting "tags".  Don't load now or we'll
     * end up loading twice. */
    return;
  }

  debug("PostLoader.load(" + extending + ", " + disable_cache + ")");

  this.preload_sample_image();

  this.loaded_extended_results = extending;

  /* Discard any running AJAX requests. */
  this.current_ajax_requests = [];

  this.result = {};
  this.result.load_options = load_options;
  this.result.tags = tags;
  this.result.disable_cache = disable_cache;

  if(this.result.tags == null)
  {
    /* If no search is specified, don't run one; return empty results. */
    this.request_finished();
    return;
  }

  /* See if we have a pool search.  This only checks for pool:id searches, not pool:*name* searches;
   * we want to know if we're displaying posts only from a single pool. */
  var pool_id = null;
  this.result.tags.split(" ").each(function(tag) {
    var m = tag.match(/^pool:(\d+)/);
    if(!m)
      return;
    pool_id = parseInt(m[1]);
  });

  /* If we're loading from a pool, load the pool's data. */
  this.result.pool_id = pool_id;

  /* Load the posts to display.  If we're loading a pool, load all posts (up to 1000);
   * otherwise set a limit. */
  var limit = extending? 1000:100;
  if(pool_id != null)
    limit = 1000;
  this.result.post_limit = limit;


  /* Make sure that request_finished doesn't consider this request complete until we've
   * actually started every request. */
  this.current_ajax_requests.push(null);

  this.server_load_pool();
  this.server_load_posts();

  this.current_ajax_requests = this.current_ajax_requests.without(null);
  this.request_finished();
}

PostLoader.prototype.hashchange_tags = function()
{
  var tags = UrlHash.get("tags");

  if(tags == this.last_seen_tags)
    return;
  this.last_seen_tags = tags;

  debug("changed tags");
  this.load();
}

PostLoader.prototype.perform_search  = function(event)
{
  var tags = event.memo.tags;
  this.last_seen_tags = tags;
  var results_mode = event.memo.results_mode || "center-on-first";
  debug("do search: " + tags);

  this.load({tags: tags, results_mode: results_mode});
}



/*
 * Handle the thumbnail view, and navigation for the main view.
 *
 * Handle a large number (thousands) of entries cleanly.  Thumbnail nodes are created
 * as needed, and destroyed when they scroll off screen.  This gives us constant
 * startup time, loads thumbnails on demand, allows preloading thumbnails in advance
 * by creating more nodes in advance, and keeps memory usage constant.
 */
ThumbnailView = function(container, view)
{
  this.container = container;
  this.view = view;
  this.post_ids = [];
  this.post_frames = [];
  this.expanded_post_idx = null;
  this.centered_post_idx = null;
  this.centered_post_offset = 0;
  this.last_mouse_x = 0;
  this.last_mouse_y = 0;
  this.thumb_container_shown = true;
  this.allow_wrapping = true;
  this.thumb_preload_container = new PreloadContainer();
  this.unused_thumb_pool = [];

  /* The [first, end) range of posts that are currently inside .post-browser-posts. */
  this.posts_populated = [0, 0];

  document.on("DOMMouseScroll", this.document_mouse_wheel_event.bindAsEventListener(this));
  document.on("mousewheel", this.document_mouse_wheel_event.bindAsEventListener(this));

  document.on("viewer:displayed-image-loaded", this.displayed_image_loaded_event.bindAsEventListener(this));
  document.on("viewer:set-active-post", function(e) {
    var post_id_and_frame = [e.memo.post_id, e.memo.post_frame];
    this.set_active_post(post_id_and_frame, e.memo.lazy, e.memo.center_thumbs);
  }.bindAsEventListener(this));
  document.on("viewer:show-next-post", function(e) { this.show_next_post(e.memo.prev); }.bindAsEventListener(this));

  document.on("viewer:scroll", function(e) { this.scroll(e.memo.left); }.bindAsEventListener(this));
  document.on("viewer:set-thumb-bar", function(e) {
    if(e.memo.toggle)
      this.show_thumb_bar(!this.thumb_container_shown);
    else
      this.show_thumb_bar(e.memo.set);
  }.bindAsEventListener(this));
  document.on("viewer:loaded-posts", this.loaded_posts_event.bindAsEventListener(this));

  this.hashchange_post_id = this.hashchange_post_id.bind(this);
  UrlHash.observe("post-id", this.hashchange_post_id);
  UrlHash.observe("post-frame", this.hashchange_post_id);

  new DragElement(this.container, { ondrag: this.container_ondrag.bind(this) });

  Element.on(window, "resize", this.window_resize_event.bindAsEventListener(this));

  this.container.on("mousemove", this.container_mousemove_event.bindAsEventListener(this));
  this.container.on("mouseover", this.container_mouseover_event.bindAsEventListener(this));
  this.container.on("mouseout", this.container_mouseout_event.bindAsEventListener(this));
  this.container.on("click", this.container_click_event.bindAsEventListener(this));
  this.container.on("dblclick", ".post-thumb,.browser-thumb-hover-overlay",
      this.container_dblclick_event.bindAsEventListener(this));

  /* Prevent the default behavior of left-clicking on the expanded thumbnail overlay.  It's
   * handled by container_click_event. */
  this.container.down(".browser-thumb-hover-overlay").on("click", function(event) {
    if(event.isLeftClick())
      event.preventDefault();
  }.bindAsEventListener(this));

  /*
   * For Android browsers, we're set to 150 DPI, which (in theory) scales us to a consistent UI size
   * based on the screen DPI.  This means that we can determine the physical screen size from the
   * window resolution: 150x150 is 1"x1".  Set a thumbnail scale based on this.  On a 320x480 HVGA
   * phone screen the thumbnails are about 2x too big, so set thumb_scale to 0.5.
   *
   * For iOS browsers, there's no way to set the viewport based on the DPI, so it's fixed at 1x.
   * (Note that on Retina screens the browser lies: even though we request 1x, it's actually at
   * 0.5x and our screen dimensions work as if we're on the lower-res iPhone screen.  We can mostly
   * ignore this.)  CSS inches aren't implemented (the DPI is fixed at 96), so that doesn't help us.
   * Fall back on special-casing individual iOS devices.
   */
  this.config = { };
  if(navigator.userAgent.indexOf("iPad") != -1)
  {
    this.config.thumb_scale = 1.0;
  }
  else if(navigator.userAgent.indexOf("iPhone") != -1 || navigator.userAgent.indexOf("iPod") != -1)
  {
    this.config.thumb_scale = 0.5;
  }
  else if(navigator.userAgent.indexOf("Android") != -1)
  {
    /* We may be in landscape or portrait; use out the narrower dimension. */
    var width = Math.min(window.innerWidth, window.innerHeight);

    /* Scale a 320-width screen to 0.5, up to 1.0 for a 640-width screen.  Remember
     * that this width is already scaled by the DPI of the screen due to target-densityDpi,
     * so these numbers aren't actually real pixels, and this scales based on the DPI
     * and size of the screen rather than the pixel count. */
    this.config.thumb_scale = scale(width, 320, 640, 0.5, 1.0);
    debug("Unclamped thumb scale: " + this.config.thumb_scale);

    /* Clamp to [0.5,1.0]. */
    this.config.thumb_scale = Math.min(this.config.thumb_scale, 1.0);
    this.config.thumb_scale = Math.max(this.config.thumb_scale, 0.5);

    debug("startup, window size: " + window.innerWidth + "x" + window.innerHeight);
  }
  else
  {
    /* Unknown device, or not a mobile device. */
    this.config.thumb_scale = 1.0;
  }
  debug("Thumb scale: " + this.config.thumb_scale);

  this.config_changed();

  /* Send the initial viewer:thumb-bar-changed event. */
  this.thumb_container_shown = false;
  this.show_thumb_bar(true);
}

ThumbnailView.prototype.window_resize_event = function(e)
{
  if(e.stopped)
    return;
  if(this.thumb_container_shown)
    this.center_on_post_for_scroll(this.centered_post_idx);
}

/* Show the given posts.  If extending is true, post_ids are meant to extend a previous
 * search; attempt to continue where we left off. */
ThumbnailView.prototype.loaded_posts_event = function(event)
{
  var post_ids = event.memo.post_ids;

  var old_post_ids = this.post_ids;
  var old_centered_post_idx = this.centered_post_idx;
  this.remove_all_posts();

  /* Filter blacklisted posts. */
  post_ids = post_ids.reject(Post.is_blacklisted);

  this.post_ids = [];
  this.post_frames = [];

  for(var i = 0; i < post_ids.length; ++i)
  {
    var post_id = post_ids[i];
    var post = Post.posts.get(post_id);
    if(post.frames.length > 0)
    {
      for(var frame_idx = 0; frame_idx < post.frames.length; ++frame_idx)
      {
        this.post_ids.push(post_id);
        this.post_frames.push(frame_idx);
      }
    }
    else
    {
      this.post_ids.push(post_id);
      this.post_frames.push(-1);
    }
  }

  this.allow_wrapping = !event.memo.can_be_extended_further;

  /* Show the results box or "no results".  Do this before updating the results box to make sure
   * the results box isn't hidden when we update, which will make offsetLeft values inside it zero
   * and break things.  If the reason we have no posts is because we didn't do a search at all,
   * don't show no-results. */
  this.container.down(".post-browser-no-results").show(event.memo.tags != null && this.post_ids.length == 0);
  this.container.down(".post-browser-posts").show(this.post_ids.length != 0);

  if(event.memo.extending)
  {
    /*
     * We're extending a previous search with more posts.  The new post list we get may
     * not line up with the old one: the post we're focused on may no longer be in the
     * search, or may be at a different index.
     *
     * Find a nearby post in the new results.  Start searching at the post we're already
     * centered on.  If that doesn't match, move outwards from there.  Only look forward
     * a little bit, or we may match a post that was never seen and jump forward too far
     * in the results.
     */
    var post_id_search_order = sort_array_by_distance(old_post_ids.slice(0, old_centered_post_idx+3), old_centered_post_idx);
    var initial_post_id = null;
    for(var i = 0; i < post_id_search_order.length; ++i)
    {
      var post_id_to_search = post_id_search_order[i];
      var post = Post.posts.get(post_id_to_search);
      if(post != null)
      {
        initial_post_id = post.id;
        break;
      }
    }
    debug("center-on-" + initial_post_id);

    /* If we didn't find anything that matched, go back to the start. */
    if(initial_post_id == null)
    {
      this.centered_post_offset = 0;
      initial_post_id = new_post_ids[0];
    }

    var center_on_post_idx = this.post_ids.indexOf(initial_post_id);
    this.center_on_post_for_scroll(center_on_post_idx);
  }
  else
  {
    /*
     * A new search has completed.
     *
     * results_mode can be one of the following:
     *
     * "center-on-first"
     * Don't change the active post.  Center the results on the first result.  This is used
     * when performing a search by clicking on a tag, where we don't want to center on the
     * post we're on (since it'll put us at some random spot in the results when the user
     * probably wants to browse from the beginning), and we don't want to change the displayed
     * post either.
     *
     * "center-on-current"
     * Don't change the active post.  Center the results on the existing current item,
     * if possible.  This is used when we want to show a new search without disrupting the
     * shown post, such as the "child posts" link in post info, and when loading the initial
     * URL hash when we start up.
     *
     * "jump-to-first"
     * Set the active post to the first result, and center on it.  This is used after making
     * a search in the tags box.
     */
    var results_mode = event.memo.load_options.results_mode || "center-on-current";

    var initial_post_id_and_frame;
    if(results_mode == "center-on-first" || results_mode == "jump-to-first")
      initial_post_id_and_frame = [this.post_ids[0], this.post_frames[0]];
    else
      initial_post_id_and_frame = this.get_current_post_id_and_frame();

    var center_on_post_idx = this.get_post_idx(initial_post_id_and_frame);
    if(center_on_post_idx == null)
      center_on_post_idx = 0;

    this.centered_post_offset = 0;
    this.center_on_post_for_scroll(center_on_post_idx);

    /* If no post is currently displayed and we just completed a search, set the current post.
     * This happens when first initializing; we wait for the first search to complete to retrieve
     * info about the post we're starting on, instead of making a separate query. */
    if(results_mode == "jump-to-first" || this.view.wanted_post_id == null)
      this.set_active_post(initial_post_id_and_frame, false, false, true);
  }

  if(event.memo.tags == null)
  {
    /* If tags is null then no search has been done, which means we're on a URL
     * with a post ID and no search, eg. "/post/browse#12345".  Hide the thumb
     * bar, so we'll just show the post. */
    this.show_thumb_bar(false);
  }
}

ThumbnailView.prototype.container_ondrag = function(e)
{
  this.centered_post_offset -= e.dX;
  this.center_on_post_for_scroll(this.centered_post_idx);
}

ThumbnailView.prototype.container_mouseover_event = function(event)
{
  var li = $(event.target);
  if(!li.hasClassName(".post-thumb"))
    li = li.up(".post-thumb");
  if(li)
    this.expand_post(li.post_idx);
}

ThumbnailView.prototype.container_mouseout_event = function(event)
{
  /* If the mouse is leaving the hover overlay, hide it. */
  var target = $(event.target);
  if(!target.hasClassName(".browser-thumb-hover-overlay"))
    target = target.up(".browser-thumb-hover-overlay");
  if(target)
    this.expand_post(null);
}

ThumbnailView.prototype.hashchange_post_id = function()
{
  var post_id_and_frame = this.get_current_post_id_and_frame();
  if(post_id_and_frame[0] == null)
    return;

  /* If we're already displaying this post, ignore the hashchange.  Don't center on the
   * post if this is just a side-effect of clicking a post, rather than the user actually
   * changing the hash. */
  var post_id = post_id_and_frame[0];
  var post_frame = post_id_and_frame[1];
  if(post_id == this.view.displayed_post_id &&
      post_frame == this.view.displayed_post_frame)
  {
//    debug("ignored-hashchange");
    return;
  }

  var new_post_idx = this.get_post_idx(post_id_and_frame);
  this.centered_post_offset = 0;
  this.center_on_post_for_scroll(new_post_idx);
  this.set_active_post(post_id_and_frame, false, false, true);
}

/* Search for the given post ID and frame in the current search results, and return its
 * index.  If the given post isn't in post_ids, return null. */
ThumbnailView.prototype.get_post_idx = function(post_id_and_frame)
{
  var post_id = post_id_and_frame[0];
  var post_frame = post_id_and_frame[1];

  var post_idx = this.post_ids.indexOf(post_id);
  if(post_idx == -1)
    return null;
  if(post_frame == -1)
    return post_idx;

  /* A post-frame is specified.  Search for a matching post-id and post-frame.  We assume
   * here that all frames for a post are grouped together in post_ids. */
  var post_frame_idx = post_idx;
  while(post_frame_idx < this.post_ids.length && this.post_ids[post_frame_idx] == post_id)
  {
    if(this.post_frames[post_frame_idx] == post_frame)
      return post_frame_idx;
    ++post_frame_idx;
  }

  /* We found a matching post, but not a matching frame.  Return the post. */
  return post_idx;
}

/* Return the post and frame that's currently being displayed in the main view, based
 * on the URL hash.  If no post is displayed and no search results are available,
 * return [null, null]. */
ThumbnailView.prototype.get_current_post_id_and_frame = function()
{
  var post_id = UrlHash.get("post-id");
  if(post_id == null)
  {
    if(this.post_ids.length == 0)
      return [null, null];
    else
      return [this.post_ids[0], this.post_frames[0]];
  }
  post_id = parseInt(post_id);

  var post_frame = UrlHash.get("post-frame");

  // If no frame is set, attempt to resolve the post_frame we'll display, if the post data
  // is already loaded.  Otherwise, post_frame will remain null.
  if(post_frame == null)
    post_frame = this.view.get_default_post_frame(post_id);

  return [post_id, post_frame];
}

/* Track the mouse cursor when it's within the container. */
ThumbnailView.prototype.container_mousemove_event = function(e)
{
  var x = e.pointerX() - document.documentElement.scrollLeft;
  var y = e.pointerY() - document.documentElement.scrollTop;
  this.last_mouse_x = x;
  this.last_mouse_y = y;
}

ThumbnailView.prototype.document_mouse_wheel_event = function(event)
{
  event.stop();

  var val;
  if(event.wheelDelta)
  {
    val = event.wheelDelta;
  } else if (event.detail) {
    val = -event.detail;
  }

  if(this.thumb_container_shown)
    document.fire("viewer:scroll", { left: val >= 0 });
  else
    document.fire("viewer:show-next-post", { prev: val >= 0 });
}

/* Set the post that's shown in the view.  The thumbs will be centered on the post
 * if center_thumbs is true.  See BrowserView.prototype.set_post for an explanation
 * of no_hash_change. */
ThumbnailView.prototype.set_active_post = function(post_id_and_frame, lazy, center_thumbs, no_hash_change, replace_history)
{
  /* If no post is specified, do nothing.  This will happen if a search returns
   * no results. */
  if(post_id_and_frame[0] == null)
    return;

  this.view.set_post(post_id_and_frame[0], post_id_and_frame[1], lazy, no_hash_change, replace_history);

  if(center_thumbs)
  {
    var post_idx = this.get_post_idx(post_id_and_frame);
    this.centered_post_offset = 0;
    this.center_on_post_for_scroll(post_idx);
  }
}

ThumbnailView.prototype.set_active_post_idx = function(post_idx, lazy, center_thumbs, no_hash_change, replace_history)
{
  if(post_idx == null)
    return;

  var post_id = this.post_ids[post_idx];
  var post_frame = this.post_frames[post_idx];
  this.set_active_post([post_id, post_frame], lazy, center_thumbs, no_hash_change, replace_history);
}

ThumbnailView.prototype.show_next_post = function(prev)
{
  if(this.post_ids.length == 0)
    return;

  var current_idx = this.get_post_idx([this.view.wanted_post_id, this.view.wanted_post_frame]);

  /* If the displayed post isn't in the thumbnails and we're changing posts, start
   * at the beginning. */
  if(current_idx == null)
    current_idx = 0;

  var add = prev? -1:+1;
  if(this.post_frames[current_idx] != this.view.wanted_post_frame && add == +1)
  {
    /*
     * We didn't find an exact match for the frame we're displaying, which usually means
     * we viewed a post frame, and then the user changed the view to the main post, and
     * the main post isn't in the thumbnails.
     *
     * It's strange to be on the main post, to hit pgdn, and to end up on the second frame
     * because the nearest match was the first frame.  Instead, we should end up on the first
     * frame.  To do that, just don't add anything to the index.
     */
    debug("Snapped the display to the nearest frame");
    if(add == +1)
      add = 0;
  }

  var new_idx = current_idx;
  new_idx += add;

  new_idx += this.post_ids.length;
  new_idx %= this.post_ids.length;

  var wrapped = (prev && new_idx > current_idx) || (!prev && new_idx < current_idx);
  if(wrapped)
  {
    /* Only allow wrapping over the edge if we've already expanded the results. */
    if(!this.allow_wrapping)
      return;
    if(!this.thumb_container_shown && prev)
      notice("Continued from the end");
    else if(!this.thumb_container_shown && !prev)
      notice("Starting over from the beginning");
  }

  this.set_active_post_idx(new_idx, true, true, false, true);
}

/* Scroll the thumbnail view left or right.  Don't change the displayed post. */
ThumbnailView.prototype.scroll = function(left)
{
  /* There's no point in scrolling the list if it's not visible. */
  if(!this.thumb_container_shown)
    return;
  var new_idx = this.centered_post_idx;

  /* If we're not centered on the post, and we're moving towards the center,
   * don't jump past the post. */
  if(this.centered_post_offset > 0 && left)
    ;
  else if(this.centered_post_offset < 0 && !left)
    ;
  else
    new_idx += (left? -1:+1);

  // Snap to the nearest post.
  this.centered_post_offset = 0;

  /* Wrap the new index. */
  if(new_idx < 0)
  {
    /* Only allow scrolling over the left edge if we've already expanded the results. */
    if(!this.allow_wrapping)
      new_idx = 0;
    else
      new_idx = this.post_ids.length - 1;
  }
  else if(new_idx >= this.post_ids.length)
  {
    if(!this.allow_wrapping)
      new_idx = this.post_ids.length - 1;
    else
      new_idx = 0;
  }

  this.center_on_post_for_scroll(new_idx);
}

/* Hide the hovered post, if any, call center_on_post(post_idx), then hover over the correct post again. */
ThumbnailView.prototype.center_on_post_for_scroll = function(post_idx)
{
  if(this.thumb_container_shown)
    this.expand_post(null);

  this.center_on_post(post_idx);

  /*
   * Now that we've re-centered, we need to expand the correct image.  Usually, we can just
   * wait for the mouseover event to fire, since we hid the expanded thumb overlay and the
   * image underneith it is now under the mouse.  However, browsers are badly broken here.
   * Opera doesn't fire mouseover events when the element under the cursor is hidden.  FF
   * fires the mouseover on hide, but misses the mouseout when the new overlay is shown, so
   * the next time it's hidden mouseover events are lost.
   *
   * Explicitly figure out which item we're hovering over and expand it.
   */
  if(this.thumb_container_shown)
  {
    var element = document.elementFromPoint(this.last_mouse_x, this.last_mouse_y);
    element = $(element);
    if(element)
    {
      var li = element.up(".post-thumb");
      if(li)
        this.expand_post(li.post_idx);
    }
  }
}

ThumbnailView.prototype.remove_post = function(right)
{
  if(this.posts_populated[0] == this.posts_populated[1])
    return false; /* none to remove */

  var node = this.container.down(".post-browser-posts");
  if(right)
  {
    --this.posts_populated[1];
    var node_to_remove = node.lastChild;
  }
  else
  {
    ++this.posts_populated[0];
    var node_to_remove = node.firstChild;
  }

  /* Remove the thumbnail that's no longer visible, and put it in unused_thumb_pool
   * so we can reuse it later.  This won't grow out of control, since we'll always use
   * an item from the pool if available rather than creating a new one. */
  var item = node.removeChild(node_to_remove);
  this.unused_thumb_pool.push(item);
  return true;
}

ThumbnailView.prototype.remove_all_posts = function()
{
  while(this.remove_post(true))
    ;
}

/* Add the next thumbnail to the left or right side. */
ThumbnailView.prototype.add_post_to_display = function(right)
{
  var node = this.container.down(".post-browser-posts");
  if(right)
  {
    var post_idx_to_populate = this.posts_populated[1];
    if(post_idx_to_populate == this.post_ids.length)
      return false;
    ++this.posts_populated[1];

    var thumb = this.create_thumb(post_idx_to_populate);
    node.insertBefore(thumb, null);
  }
  else
  {
    if(this.posts_populated[0] == 0)
      return false;
    --this.posts_populated[0];
    var post_idx_to_populate = this.posts_populated[0];
    var thumb = this.create_thumb(post_idx_to_populate);
    node.insertBefore(thumb, node.firstChild);
  }
  return true;
}

/* Fill the container so post_idx is visible. */
ThumbnailView.prototype.populate_post = function(post_idx)
{
  if(this.is_post_idx_shown(post_idx))
    return;

  /* If post_idx is on the immediate border of what's already displayed, add it incrementally, and
   * we'll cull extra posts later.  Otherwise, clear all of the posts and populate from scratch. */
  if(post_idx == this.posts_populated[1])
  {
    this.add_post_to_display(true);
    return;
  }
  else if(post_idx == this.posts_populated[0])
  {
    this.add_post_to_display(false);
    return;
  }

  /* post_idx isn't on the boundary, so we're jumping posts rather than scrolling.
   * Clear the container and start over. */ 
  this.remove_all_posts();

  var node = this.container.down(".post-browser-posts");

  var thumb = this.create_thumb(post_idx);
  node.appendChild(thumb);
  this.posts_populated[0] = post_idx;
  this.posts_populated[1] = post_idx + 1;
}

ThumbnailView.prototype.is_post_idx_shown = function(post_idx)
{
  if(post_idx >= this.posts_populated[1])
    return false;
  return post_idx >= this.posts_populated[0];
}

/* Return the total width of all thumbs to the left or right of post_idx, not
 * including itself. */
ThumbnailView.prototype.get_width_adjacent_to_post = function(post_idx, right)
{
  var post = $("p" + post_idx);
  if(right)
  {
    var rightmost_node = post.parentNode.lastChild;
    if(rightmost_node == post)
      return 0;
    var right_edge = rightmost_node.offsetLeft + rightmost_node.offsetWidth;
    var center_post_right_edge = post.offsetLeft + post.offsetWidth;
    return right_edge - center_post_right_edge
  }
  else
  {
    return post.offsetLeft;
  }
}

/* Center the thumbnail strip on post_idx.  If post_id isn't in the display, do nothing.
 * Fire viewer:need-more-thumbs if we're scrolling near the edge of the list. */
ThumbnailView.prototype.center_on_post = function(post_idx)
{
  if(!this.post_ids)
  {
    debug("unexpected: center_on_post has no post_ids");
    return;
  }

  var post_id = this.post_ids[post_idx];
  if(Post.posts.get(post_id) == null)
    return;

  if(post_idx > this.post_ids.length*3/4)
  {
    /* We're coming near the end of the loaded posts, so load more.  We may be currently
     * in the middle of setting up the post; defer this, so we finish what we're doing first. */
    (function() {
      document.fire("viewer:need-more-thumbs", { view: this });
    }).defer();
  }

  this.centered_post_idx = post_idx;

  /* If we're not expanded, we can't figure out how to center it since we'll have no width.
   * Also, don't cause thumbnails to be loaded if we're hidden.  Just set centered_post_idx,
   * and we'll come back here when we're displayed. */
  if(!this.thumb_container_shown)
    return;

  /* If centered_post_offset is high enough to put the actual center post somewhere else,
   * adjust it towards zero and change centered_post_idx.  This keeps centered_post_idx
   * pointing at the item that's actually centered. */
  while(1)
  {
    var post = $("p" + this.centered_post_idx);
    if(!post)
      break;
    var pos = post.offsetWidth/2 + this.centered_post_offset;
    if(pos >= 0 && pos < post.offsetWidth)
      break;

    var next_post_idx = this.centered_post_idx + (this.centered_post_offset > 0? +1:-1);
    var next_post = $("p" + next_post_idx);
    if(next_post == null)
      break;

    var current_post_center = post.offsetLeft + post.offsetWidth/2;
    var next_post_center = next_post.offsetLeft + next_post.offsetWidth/2;
    var distance = next_post_center - current_post_center;
    this.centered_post_offset -= distance;
    this.centered_post_idx = next_post_idx;

    post_idx = this.centered_post_idx;
    break;
  }

  this.populate_post(post_idx);

  /* Make sure that we have enough posts populated around the one we're centering
   * on to fill the display.  If we have too many nodes, remove some. */
  for(var direction = 0; direction < 2; ++direction)
  {
    var right = !!direction;

    /* We need at least this.container.offsetWidth/2 in each direction.  Load a little more, to
     * reduce flicker. */
    var minimum_distance = this.container.offsetWidth/2;
    minimum_distance *= 1.25;
    var maximum_distance = minimum_distance + 500;
    while(true)
    {
      var added = false;
      var width = this.get_width_adjacent_to_post(post_idx, right);

      /* If we're offset to the right then we need more data to the left, and vice versa. */
      width += this.centered_post_offset * (right? -1:+1);
      if(width < 0)
        width = 1;

      if(width < minimum_distance)
      {
        /* We need another post.  Stop if there are no more posts to add. */
        if(!this.add_post_to_display(right))
          break;
        added = false;
      }
      else if(width > maximum_distance)
      {
        /* We have a lot of posts off-screen.  Remove one. */
        this.remove_post(right);

        /* Sanity check: we should never add and remove in the same direction.  If this
         * happens, the distance between minimum_distance and maximum_distance may be less
         * than the width of a single thumbnail. */
        if(added)
        {
          alert("error");
          break;
        }
      }
      else
      {
        break;
      }
    }
  }

  this.preload_thumbs();

  /* We always center the thumb.  Don't clamp to the edge when we're near the first or last
   * item, so we always have empty space on the sides for expanded landscape thumbnails to
   * be visible. */
  var thumb = $("p" + post_idx);
  var center_on_position = this.container.offsetWidth/2;

  var shift_pixels_right = center_on_position - thumb.offsetWidth/2 - thumb.offsetLeft;
  shift_pixels_right -= this.centered_post_offset;
  shift_pixels_right = Math.round(shift_pixels_right);

  var node = this.container.down(".post-browser-scroller");
  node.setStyle({left: shift_pixels_right + "px"});
}

/* Preload thumbs on the boundary of what's actually displayed. */
ThumbnailView.prototype.preload_thumbs = function()
{
  var post_idxs = [];
  for(var i = 0; i < 5; ++i)
  {
    var preload_post_idx = this.posts_populated[0] - i - 1;
    if(preload_post_idx >= 0)
      post_idxs.push(preload_post_idx);

    var preload_post_idx = this.posts_populated[1] + i;
    if(preload_post_idx < this.post_ids.length)
      post_idxs.push(preload_post_idx);
  }

  /* Remove any preloaded thumbs that are no longer in the preload list. */
  this.thumb_preload_container.get_all().each(function(element) {
    var post_idx = element.post_idx;
    if(post_idxs.indexOf(post_idx) != -1)
    {
      /* The post is staying loaded.  Clear the value in post_idxs, so we don't load it
       * again down below. */
      post_idxs[post_idx] = null;
      return;
    }

    /* The post is no longer being preloaded.  Remove the preload. */
    this.thumb_preload_container.cancel_preload(element);
  }.bind(this));

  /* Add new preloads. */
  for(var i = 0; i < post_idxs.length; ++i)
  {
    var post_idx = post_idxs[i];
    if(post_idx == null)
      continue;

    var post_id = this.post_ids[post_idx];
    var post = Post.posts.get(post_id);

    var post_frame = this.post_frames[post_idx];
    var url;
    if(post_frame != -1)
      url = post.frames[post_frame].preview_url;
    else
      url = post.preview_url;

    var element = this.thumb_preload_container.preload(url);
    element.post_idx = post_idx;
  }
}

ThumbnailView.prototype.expand_post = function(post_idx)
{
  /* Thumbs on click for touchpads doesn't make much sense anyway--touching the thumb causes it
   * to be loaded.  It also triggers a bug in iPhone WebKit (covering up the original target of
   * a mouseover during the event seems to cause the subsequent click event to not be delivered).
   * Just disable hover thumbnails for touchscreens.  */
  if(Prototype.BrowserFeatures.Touchscreen)
    return;

  if(!this.thumb_container_shown)
    return;

  var post_id = this.post_ids[post_idx];

  var overlay = this.container.down(".browser-thumb-hover-overlay");
  overlay.hide();
  overlay.down("IMG").src = "about:blank";

  this.expanded_post_idx = post_idx;
  if(post_idx == null)
    return;

  var post = Post.posts.get(post_id);
  if(post.status == "deleted")
    return;

  var thumb = $("p" + post_idx);

  var bottom = this.container.down(".browser-bottom-bar").offsetHeight;
  overlay.style.bottom = bottom + "px";

  var post_frame = this.post_frames[post_idx];
  var image_width, image_url;
  if(post_frame != -1)
  {
    var frame = post.frames[post_frame];
    image_width = frame.preview_width;
    image_url = frame.preview_url;
  }
  else
  {
    image_width = post.actual_preview_width;
    image_url = post.preview_url;
  }

  var left = thumb.cumulativeOffset().left - image_width/2 + thumb.offsetWidth/2;
  overlay.style.left = left + "px";

  /* If the hover thumbnail overflows the right edge of the viewport, it'll extend the document and
   * allow scrolling to the right, which we don't want.  overflow: hidden doesn't fix this, since this
   * element is absolutely positioned.  Set the max-width to clip the right side of the thumbnail if
   * necessary. */
  var max_width = document.viewport.getDimensions().width - left;
  overlay.style.maxWidth = max_width + "px";
  overlay.href = "/post/browse#" + post.id + this.view.post_frame_hash(post, post_frame);
  overlay.down("IMG").src = image_url;
  overlay.show();
}

ThumbnailView.prototype.create_thumb = function(post_idx)
{
  var post_id = this.post_ids[post_idx];
  var post_frame = this.post_frames[post_idx];

  var post = Post.posts.get(post_id);

  /*
   * Reuse thumbnail blocks that are no longer in use, to avoid WebKit memory leaks: it
   * doesn't like creating and deleting lots of images (or blocks with images inside them).
   *
   * Thumbnails are hidden until they're loaded, so we don't show ugly load-borders.  This
   * also keeps us from showing old thumbnails before the new image is loaded.  Use visibility:
   * hidden, not display: none, or the size of the image won't be defined, which breaks
   * center_on_post.
   */
  if(this.unused_thumb_pool.length == 0)
  {
    var div =
      '<div class="inner">' +
        '<a class="thumb" tabindex="-1">' +
          '<img alt="" class="preview" onload="this.style.visibility = \'visible\';">' +
        '</a>' +
      '</div>';
    var item = $(document.createElement("li"));
    item.innerHTML = div;
    item.className = "post-thumb";
  }
  else
  {
    var item = this.unused_thumb_pool.pop();
  }
    
  item.id = "p" + post_idx;
  item.post_idx = post_idx;
  item.down("A").href = "/post/browse#" + post.id + this.view.post_frame_hash(post, post_frame);

  /* If the image is already what we want, then leave it alone.  Setting it to what it's
   * already set to won't necessarily cause onload to be fired, so it'll never be set
   * back to visible. */
  var img = item.down("IMG");
  var url;
  if(post_frame != -1)
    url = post.frames[post_frame].preview_url;
  else
    url = post.preview_url;
  if(img.src != url)
  {
    img.style.visibility = "hidden";
    img.src = url;
  }

  this.set_thumb_dimensions(item);
  return item;
}

ThumbnailView.prototype.set_thumb_dimensions = function(li)
{
  var post_idx = li.post_idx;
  var post_id = this.post_ids[post_idx];
  var post_frame = this.post_frames[post_idx];
  var post = Post.posts.get(post_id);

  var width, height;
  if(post_frame != -1)
  {
    var frame = post.frames[post_frame];
    width = frame.preview_width;
    height = frame.preview_height;
  }
  else
  {
    width = post.actual_preview_width;
    height = post.actual_preview_height;
  }

  width *= this.config.thumb_scale;
  height *= this.config.thumb_scale;

  /* This crops blocks that are too wide, but doesn't pad them if they're too
   * narrow, since that creates odd spacing. 
   *
   * If the height of this block is changed, adjust .post-browser-posts-container in
   * config_changed. */
  var block_size = [Math.min(width, 200 * this.config.thumb_scale), 200 * this.config.thumb_scale];
  var crop_left = Math.round((width - block_size[0]) / 2);
  var pad_top = Math.max(0, block_size[1] - height);

  var inner = li.down(".inner");
  inner.actual_width = block_size[0];
  inner.actual_height = block_size[1];
  inner.setStyle({width: block_size[0] + "px", height: block_size[1] + "px"});

  var img = inner.down("img");
  img.width = width;
  img.height = height;
  img.setStyle({marginTop: pad_top + "px", marginLeft: -crop_left + "px"});
}

ThumbnailView.prototype.config_changed = function()
{
  /* Adjust the size of the container to fit the thumbs at the current scale.  They're the
   * height of the thumb block, plus ten pixels for padding at the top and bottom. */
  var container_height = 200*this.config.thumb_scale + 10;
  this.container.down(".post-browser-posts-container").setStyle({height: container_height + "px"});

  this.container.select("LI.post-thumb").each(this.set_thumb_dimensions.bind(this));

  this.center_on_post_for_scroll(this.centered_post_idx);
}

/* Handle clicks and doubleclicks on thumbnails.  These events are handled by
 * the container, so we don't need to put event handlers on every thumb. */
ThumbnailView.prototype.container_click_event = function(event)
{
  /* Ignore the click if it was stopped by the DragElement. */
  if(event.stopped)
    return;

  if($(event.target).up(".browser-thumb-hover-overlay"))
  {
    /* The hover overlay was clicked.  When the user clicks a thumbnail, this is
     * usually what happens, since the hover overlay covers the actual thumbnail. */
    this.set_active_post_idx(this.expanded_post_idx);
    event.preventDefault();
    return;
  }

  var li = $(event.target).up(".post-thumb");
  if(li == null)
    return;

  /* An actual thumbnail was clicked.  This can happen if we don't have the expanded
   * thumbnails for some reason. */
  event.preventDefault();
  this.set_active_post_idx(li.post_idx);
}

ThumbnailView.prototype.container_dblclick_event = function(event)
{
  if(event.button)
    return;

  event.preventDefault();
  this.show_thumb_bar(false);
}

ThumbnailView.prototype.show_thumb_bar = function(shown)
{
  if(this.thumb_container_shown == shown)
    return;
  this.thumb_container_shown = shown;
  this.container.show(shown);

  /* If the centered post was changed while we were hidden, it wasn't applied by
   * center_on_post, so do it now. */
  this.center_on_post_for_scroll(this.centered_post_idx);

  document.fire("viewer:thumb-bar-changed", {
    shown: this.thumb_container_shown,
    height: this.thumb_container_shown? this.container.offsetHeight:0
  });
}

/* Return the next or previous post, wrapping around if necessary. */
ThumbnailView.prototype.get_adjacent_post_idx_wrapped = function(post_idx, next)
{
  post_idx += next? +1:-1;
  post_idx = (post_idx + this.post_ids.length) % this.post_ids.length;
  return post_idx;
}

ThumbnailView.prototype.displayed_image_loaded_event = function(event)
{
  /* If we don't have a loaded search, then we don't have any nearby posts to preload. */
  if(this.post_ids == null)
    return;

  var post_id = event.memo.post_id;
  var post_frame = event.memo.post_frame;
  var post_idx = this.get_post_idx([post_id, post_frame]);
  if(post_idx == null)
    return;

  /*
   * The image in the post we're displaying is finished loading.
   *
   * Preload the next and previous posts.  Normally, one or the other of these will
   * already be in cache.
   *
   * Include the current post in the preloads, so if we switch from a frame back to
   * the main image, the frame itself will still be loaded.
   */
  var post_ids_to_preload = [];
  post_ids_to_preload.push([this.post_ids[post_idx], this.post_frames[post_idx]]);
  var adjacent_post_idx = this.get_adjacent_post_idx_wrapped(post_idx, true);
  if(adjacent_post_idx != null)
    post_ids_to_preload.push([this.post_ids[adjacent_post_idx], this.post_frames[adjacent_post_idx]]);
  var adjacent_post_idx = this.get_adjacent_post_idx_wrapped(post_idx, false);
  if(adjacent_post_idx != null)
    post_ids_to_preload.push([this.post_ids[adjacent_post_idx], this.post_frames[adjacent_post_idx]]);
  this.view.preload(post_ids_to_preload);
}


/* This handler handles global keypress bindings, and fires viewer: events. */
function InputHandler()
{
  TrackFocus();

  /*
   * Keypresses are aggrevating:
   *
   * Opera can only stop key events from keypress, not keydown.
   *
   * Chrome only sends keydown for non-alpha keys, not keypress.
   *
   * In Firefox, keypress's keyCode value for non-alpha keys is always 0.
   *
   * Alpha keys can always be detected with keydown.  Don't use keypress; Opera only provides
   * charCode to that event, and it's affected by the caps state, which we don't want.
   *
   * Use OnKey for alpha key bindings.  For other keys, use keypress in Opera and FF and
   * keydown in other browsers.
   */
  var keypress_event_name = window.opera || Prototype.Browser.Gecko? "keypress":"keydown";
  document.on(keypress_event_name, this.document_keypress_event.bindAsEventListener(this));
}

InputHandler.prototype.handle_keypress = function(e)
{
  var key = e.charCode;
  if(!key)
    key = e.keyCode; /* Opera */
  if(key == Event.KEY_ESC)
  {
    if(document.focusedElement && document.focusedElement.blur && !document.focusedElement.hasClassName("no-blur-on-escape"))
    {
      document.focusedElement.blur();
      return true;
    }
  }

  var target = e.target;
  if(target.tagName == "INPUT" || target.tagName == "TEXTAREA")
    return false;

  if(key == 63) // ?, f
  {
    debug("xxx");
    document.fire("viewer:show-help");
    return true;
  }

  if (e.shiftKey || e.altKey || e.ctrlKey || e.metaKey)
    return false;
  var grave_keycode = Prototype.Browser.WebKit? 192: 96;
  if(key == 32) // space
    document.fire("viewer:set-thumb-bar", { toggle: true });
  else if(key == 49) // 1
    document.fire("viewer:vote", { score: 1 });
  else if(key == 50) // 2
    document.fire("viewer:vote", { score: 2 });
  else if(key == 51) // 3
    document.fire("viewer:vote", { score: 3 });
  else if(key == grave_keycode) // `
    document.fire("viewer:vote", { score: 0 });
  else if(key == 65 || key == 97) // A, b
    document.fire("viewer:show-next-post", { prev: true });
  else if(key == 69 || key == 101) // E, e
    document.fire("viewer:edit-post");
  else if(key == 83 || key == 115) // S, s
    document.fire("viewer:show-next-post", { prev: false });
  else if(key == 70 || key == 102) // F, f
    document.fire("viewer:focus-tag-box");
  else if(key == 86 || key == 118) // V, v
    document.fire("viewer:view-large-toggle");
  else if(key == Event.KEY_PAGEUP)
    document.fire("viewer:show-next-post", { prev: true });
  else if(key == Event.KEY_PAGEDOWN)
    document.fire("viewer:show-next-post", { prev: false });
  else if(key == Event.KEY_LEFT)
    document.fire("viewer:scroll", { left: true });
  else if(key == Event.KEY_RIGHT)
    document.fire("viewer:scroll", { left: false });
  else
    return false;
  return true;
}

InputHandler.prototype.document_keypress_event = function(e)
{
  //alert(e.charCode + ", " + e.keyCode);
  if(this.handle_keypress(e))
    e.stop();
}



/*
 * We have a few competing goals:
 *
 * First, be as responsive as possible.  Preload nearby post HTML and their images.
 *
 * If data in a post page changes, eg. if the user votes, then coming back to the page
 * later should retain the changes.  This means either requesting the page again, or
 * retaining the document node and reusing it, so we preserve the changes that were
 * made in-place.
 *
 * Don't use too much memory.  If we keep every document node in memory as we use it,
 * the images will probably be kept around too.  Release older nodes, so the browser
 * is more likely to release images that havn't been used in a while.
 *
 * We do the following:
 * - When we load a new post, it's formatted and its scripts are evaluated normally.
 * - When we're replacing the displayed post, its node is stashed away in a node cache.
 * - If we come back to the post while it's in the node cache, we'll use the node directly.
 * - HTML and images for posts are preloaded.  We don't use a simple mechanism like
 *   Preload.preload_raw, because Opera's caching is broken for XHR and it'll always
 *   do a slow revalidation.
 * - We don't depend on browser caching for HTML.  That would require us to expire a
 *   page when we switch away from it if we've made any changes (eg. voting), so we
 *   don't pull an out-of-date page next time.  This is slower, and would require us
 *   to be careful about expiring the cache.
 */

BrowserView = function(container)
{
  this.container = container;

  /* The post that we currently want to display.  This will be either one of the
   * current html_preloads, or be the displayed_post_id. */
  this.wanted_post_id = null;
  this.wanted_post_frame = null;

  /* The post that's currently actually being displayed. */
  this.displayed_post_id = null;
  this.displayed_post_frame = null;

  this.current_ajax_request = null;
  this.last_preload_request = [];
  this.last_preload_request_active = false;

  this.image_pool = new ImgPoolHandler();
  this.img_box = this.container.down(".image-box");
  this.container.down(".image-canvas");

  /* In Opera 10.63, the img.complete property is not reset to false after changing the
   * src property.  Blits from images to the canvas silently fail, with nothing being
   * blitted and no exception raised.  This causes blank canvases to be displayed, because
   * we have no way of telling whether the image is blittable or if the blit succeeded. */
  if(!Prototype.Browser.Opera)
    this.canvas = create_canvas_2d();
  if(this.canvas)
  {
    this.canvas.hide();
    this.img_box.appendChild(this.canvas);
  }
  this.zoom_level = 0;

  /* True if the post UI is visible. */
  this.post_ui_visible = true;

  this.update_navigator = this.update_navigator.bind(this);

  Event.on(window, "resize", this.window_resize_event.bindAsEventListener(this));
  document.on("viewer:vote", function(event) { if(this.vote_widget) this.vote_widget.vote(event.memo.score); }.bindAsEventListener(this));

  if(TagCompletion)
    TagCompletion.init();

  /* Double-clicking the main image, or on nothing, toggles the thumb bar. */
  this.container.down(".image-container").on("dblclick", ".image-container", function(event) {
    /* Watch out: Firefox fires dblclick events for all buttons, with the standard
     * button maps, but IE only fires it for left click and doesn't set button at
     * all, so event.isLeftClick won't work. */
    if(event.button)
      return;

    event.stop();
    document.fire("viewer:set-thumb-bar", {toggle: true});
  }.bindAsEventListener(this));

  /* Image controls: */
  document.on("viewer:view-large-toggle", function(e) { this.toggle_view_large_image(); }.bindAsEventListener(this));
  this.container.down(".post-info").on("click", ".toggle-zoom", function(e) { e.stop(); this.toggle_view_large_image(); }.bindAsEventListener(this));
  this.container.down(".parent-post").down("A").on("click", this.parent_post_click_event.bindAsEventListener(this));
  this.container.down(".child-posts").down("A").on("click", this.child_posts_click_event.bindAsEventListener(this));

  this.container.down(".post-frames").on("click", ".post-frame-link", function(e, item) {
    e.stop();

    /* Change the displayed post frame to the one that was clicked.  Since all post frames
     * are usually displayed in the thumbnail view, set center_thumbs to true to recenter
     * on the thumb that was clicked, so it's clearer what's happening. */
    document.fire("viewer:set-active-post", {post_id: this.displayed_post_id, post_frame: item.post_frame, center_thumbs: true});
  }.bind(this));

  /* We'll receive this message from the thumbnail view when the overlay is
   * visible on the bottom of the screen, to tell us how much space is covered up
   * by it. */
  this.thumb_bar_height = 0;
  document.on("viewer:thumb-bar-changed", function(e) {
    /* Update the thumb bar height and rescale the image to fit the new area. */
    this.thumb_bar_height = e.memo.height;
    this.update_image_window_size();

    this.set_post_ui(e.memo.shown);
    this.scale_and_position_image(true);
  }.bindAsEventListener(this));

/*
  OnKey(79, null, function(e) {
    this.zoom_level -= 1;
    this.scale_and_position_image(true);
    this.update_navigator();
    return true;
  }.bindAsEventListener(this));

  OnKey(80, null, function(e) {
    this.zoom_level += 1;
    this.scale_and_position_image(true);
    this.update_navigator();
    return true;
  }.bindAsEventListener(this));
*/
  /* Hide member-only and moderator-only controls: */
  $(document.body).pickClassName("is-member", "not-member", User.is_member_or_higher());
  $(document.body).pickClassName("is-moderator", "not-moderator", User.is_mod_or_higher());

  var tag_span = this.container.down(".post-tags");
  tag_span.on("click", ".post-tag", function(e, element) {
    e.stop();
    document.fire("viewer:perform-search", {tags: element.tag_name});
  }.bind(this));

  /* These two links do the same thing, but one is shown to approve a pending post
   * and the other is shown to unflag a flagged post, so they prompt differently. */
  this.container.down(".post-approve").on("click", function(e) {
    e.stop();
    if(!confirm("Approve this post?"))
      return;
    var post_id = this.displayed_post_id;
    Post.approve(post_id, false);
  }.bindAsEventListener(this));

  this.container.down(".post-unflag").on("click", function(e) {
    e.stop();
    if(!confirm("Unflag this post?"))
      return;
    var post_id = this.displayed_post_id;
    Post.unflag(post_id);
  }.bindAsEventListener(this));

  this.container.down(".post-delete").on("click", function(e) {
    e.stop();
    var post = Post.posts.get(this.displayed_post_id);
    var default_reason = "";
    if(post.flag_detail)
      default_reason = post.flag_detail.reason;

    var reason = prompt("Reason:", default_reason);
    if(!reason || reason == "")
      return;
    var post_id = this.displayed_post_id;
    Post.approve(post_id, reason);
  }.bindAsEventListener(this));

  this.container.down(".post-undelete").on("click", function(e) {
    e.stop();
    if(!confirm("Undelete this post?"))
      return;
    var post_id = this.displayed_post_id;
    Post.undelete(post_id);
  }.bindAsEventListener(this));
  
  this.container.down(".flag-button").on("click", function(e) {
    e.stop();
    var post_id = this.displayed_post_id;
    Post.flag(post_id);
  }.bindAsEventListener(this));

  this.container.down(".activate-post").on("click", function(e) {
    e.stop();

    var post_id = this.displayed_post_id;
    if(!confirm("Activate this post?"))
      return;
    Post.update_batch([{ id: post_id, is_held: false }], function()
    {
      var post = Post.posts.get(post_id);
      if(post.is_held)
        notice("Couldn't activate post");
      else
        notice("Activated post");
    }.bind(this));
  }.bindAsEventListener(this));

  this.container.down(".reparent-post").on("click", function(e) {
    e.stop();

    if(!confirm("Make this post the parent?"))
      return;

    var post_id = this.displayed_post_id;
    var post = Post.posts.get(post_id);
    if(post == null)
      return;

    Post.reparent_post(post_id, post.parent_id, false);
  }.bindAsEventListener(this));

  this.container.down(".pool-info").on("click", ".remove-pool-from-post", function(e, element)
  {
    e.stop();
    var pool_info = element.up(".pool-info");
    var pool = Pool.pools.get(pool_info.pool_id);
    var pool_name = pool.name.replace(/_/g, ' ');
    if(!confirm("Remove this post from pool #" + pool_info.pool_id + ": " + pool_name + "?"))
      return;

    Pool.remove_post(pool_info.post_id, pool_info.pool_id);
  }.bind(this));
  
  /* Post editing: */
  var post_edit = this.container.down(".post-edit");
  post_edit.down("FORM").on("submit", function(e) { e.stop(); this.edit_save(); }.bindAsEventListener(this));
  this.container.down(".show-tag-edit").on("click", function(e) { e.stop(); this.edit_show(true); }.bindAsEventListener(this));
  this.container.down(".edit-save").on("click", function(e) { e.stop(); this.edit_save(); }.bindAsEventListener(this));
  this.container.down(".edit-cancel").on("click", function(e) { e.stop(); this.edit_show(false); }.bindAsEventListener(this));

  this.edit_post_area_changed = this.edit_post_area_changed.bind(this);
  post_edit.down(".edit-tags").on("paste", function(e) { this.edit_post_area_changed.defer(); }.bindAsEventListener(this));
  post_edit.down(".edit-tags").on("keydown", function(e) { this.edit_post_area_changed.defer(); }.bindAsEventListener(this));
  new TagCompletionBox(post_edit.down(".edit-tags"));

  this.container.down(".post-edit").on("keydown", function(e) {
    /* Don't e.stop() KEY_ESC, so we fall through and let handle_keypress unfocus the
     * form entry, if any.  Otherwise, Chrome gets confused and leaves the focus on the
     * hidden input, where it'll steal keystrokes. */
    if (e.keyCode == Event.KEY_ESC) { this.edit_show(false); }
    else if (e.keyCode == Event.KEY_RETURN) { e.stop(); this.edit_save(); }
  }.bindAsEventListener(this));

  /* When the edit-post hotkey is pressed (E), force the post UI open and show editing. */
  document.on("viewer:edit-post", function(e) {
    document.fire("viewer:set-thumb-bar", { set: true });
    this.edit_show(true);
  }.bindAsEventListener(this));

  /* When the post that's currently being displayed is updated by an API call, update
   * the displayed info. */
  document.on("posts:update", function(e) {
    if(e.memo.post_ids.get(this.displayed_post_id) == null)
      return;
    this.set_post_info();
  }.bindAsEventListener(this));

  this.vote_widget = new VoteWidget(this.container.down(".vote-container"));

  this.blacklist_override_post_id = null;
  this.container.down(".show-blacklisted").on("click", function(e) { e.preventDefault(); }.bindAsEventListener(this));
  this.container.down(".show-blacklisted").on("dblclick", function(e) {
    e.stop();
    this.blacklist_override_post_id = this.displayed_post_id;
    var post = Post.posts.get(this.displayed_post_id);
    this.set_main_image(post, this.displayed_post_frame);
  }.bindAsEventListener(this));


  this.img_box.on("viewer:center-on", function(e) { this.center_image_on(e.memo.x, e.memo.y); }.bindAsEventListener(this));

  this.navigator = new Navigator(this.container.down(".image-navigator"), this.img_box);

  this.container.on("swipe:horizontal", function(e) { document.fire("viewer:show-next-post", { prev: e.memo.right }); }.bindAsEventListener(this));

  if(Prototype.BrowserFeatures.Touchscreen)
  {
    this.create_voting_popup();
    this.image_swipe = new SwipeHandler(this.container.down(".image-container"));
  }

  /* Create the frame editor.  This must be created before image_dragger, since it takes priority
   * for drags. */
  this.container.down(".edit-frames-button").on("click", function(e) { e.stop(); this.show_frame_editor(); }.bindAsEventListener(this));
  this.frame_editor = new FrameEditor(this.container.down(".frame-editor"), this.img_box, this.container.down(".frame-editor-popup"),
  {
    onClose: function() {
      this.hide_frame_editor();
    }.bind(this)
  });

  /* If we're using dragging as a swipe gesture (see SwipeHandler), don't use it for
   * dragging too. */
  if(this.image_swipe == null)
    this.image_dragger = new WindowDragElementAbsolute(this.img_box, this.update_navigator);
}

BrowserView.prototype.create_voting_popup = function()
{
  /* Create the low-level voting widget. */
  var popup_vote_widget_container = this.container.down(".vote-popup-container");
  popup_vote_widget_container.show();
  this.popup_vote_widget = new VoteWidget(popup_vote_widget_container);

  var flash = this.container.down(".vote-popup-flash");

  /* vote-popup-expand is the part that's always present and is clicked to display the
   * voting popup.  Create a dragger on it, and pass the position down to the voting
   * popup as we drag around. */
  var popup_expand = this.container.down(".vote-popup-expand");
  popup_expand.show();

  var last_dragged_over = null;

  this.popup_vote_dragger = new DragElement(popup_expand, {
    ondown: function(drag) {
      /* Stop the touchdown/mousedown events, so this drag takes priority over any
       * others.  In particular, we don't want this.image_swipe to also catch this
       * as a drag. */
      drag.latest_event.stop();

      flash.hide();
      flash.removeClassName("flash-star");

      this.popup_vote_widget.set_mouseover(null);
      last_dragged_over = null;
      popup_vote_widget_container.removeClassName("vote-popup-hidden");
    }.bind(this),

    onup: function(drag) {
      /* If we're cancelling the drag, don't activate the vote, if any. */
      if(drag.cancelling)
      {
        debug("cancelling drag");
        last_dragged_over = null;
      }

      /* Call even if star_container is null or not a star, so we clear any mouseover. */
      this.popup_vote_widget.set_mouseover(last_dragged_over);

      var star = this.popup_vote_widget.activate_item(last_dragged_over);

      /* If a vote was made, flash the vote star. */
      if(star != null)
      {
        /* Set the star-# class to color the star. */
        for(var i = 0; i < 4; ++i)
          flash.removeClassName("star-" + i);
        flash.addClassName("star-" + star);

        flash.show();

        /* Center the element on the screen. */
        var offset = this.image_window_size;
        var flash_x = offset.width/2 - flash.offsetWidth/2;
        var flash_y = offset.height/2 - flash.offsetHeight/2;
        flash.setStyle({left: flash_x + "px", top: flash_y + "px"});
        flash.addClassName("flash-star");
      }

      popup_vote_widget_container.addClassName("vote-popup-hidden");
      last_dragged_over = null;
    }.bind(this),

    ondrag: function(drag) {
      last_dragged_over = document.elementFromPoint(drag.x, drag.y);
      this.popup_vote_widget.set_mouseover(last_dragged_over);
    }.bind(this)
  });
}


BrowserView.prototype.set_post_ui = function(visible)
{
  /* Disable the post UI by default on touchscreens; we don't have an interface
   * to toggle it. */
  if(Prototype.BrowserFeatures.Touchscreen)
    visible = false;

  /* If we don't have a post displayed, always hide the post UI even if it's currently
   * shown. */
  this.container.down(".post-info").show(visible && this.displayed_post_id != null);

  if(visible == this.post_ui_visible)
    return;

  this.post_ui_visible = visible;
  if(this.navigator)
    this.navigator.set_autohide(!visible);

  /* If we're hiding the post UI, cancel the post editor if it's open. */
  if(!this.post_ui_visible)
    this.edit_show(false);
}


BrowserView.prototype.image_loaded_event = function(event)
{
  /* Record that the image is completely available, so it can be blitted to the canvas.
   * This is different than img.complete, which is true if the image has completed downloading
   * but hasn't yet been decoded, so isn't yet completely available.  This generally happens
   * if we query img.completed quickly after setting img.src and the image data is cached. */
  this.img.fully_loaded = true;

  document.fire("viewer:displayed-image-loaded", { post_id: this.displayed_post_id, post_frame: this.displayed_post_frame });
  this.update_canvas();
}

/* Return true if last_preload_request includes [post_id, post_frame]. */
BrowserView.prototype.post_frame_list_includes = function(post_id_list, post_id, post_frame)
{
  var found_preload = post_id_list.find(function(post) { return post[0] == post_id && post[1] == post_frame; });
  return found_preload != null;
}

/* Begin preloading the HTML and images for the given post IDs. */
BrowserView.prototype.preload = function(post_ids)
{
  /* We're being asked to preload post_ids.  Only do this if it seems to make sense: if
   * the user is actually traversing posts that are being preloaded.  Look at the previous
   * call to preload().  If it didn't include the current post, then skip the preload. */
  var last_preload_request = this.last_preload_request;
  this.last_preload_request = post_ids;

  if(!this.post_frame_list_includes(last_preload_request, this.wanted_post_id, this.wanted_post_frame))
  {
    // debug("skipped-preload(" + post_ids.join(",") + ")");
    this.last_preload_request_active = false;
    return;
  }
  this.last_preload_request_active = true;
  // debug("preload(" + post_ids.join(",") + ")");
  
  var new_preload_container = new PreloadContainer();
  for(var i = 0; i < post_ids.length; ++i)
  {
    var post_id = post_ids[i][0];
    var post_frame = post_ids[i][1];
    var post = Post.posts.get(post_id);

    if(post_frame != -1)
    {
      var frame = post.frames[post_frame];
      new_preload_container.preload(frame.url);
    }
    else
      new_preload_container.preload(post.sample_url);
  }

  /* If we already were preloading images, we created the new preloads before
   * deleting the old ones.  That way, any images that are still being preloaded
   * won't be deleted and recreated, possibly causing the download to be interrupted
   * and resumed. */
  if(this.preload_container)
    this.preload_container.destroy();
  this.preload_container = new_preload_container;
}

BrowserView.prototype.load_post_id_data = function(post_id)
{
  debug("load needed");

  // If we already have a request in flight, don't start another; wait for the
  // first to finish.
  if(this.current_ajax_request != null)
    return;

  new Ajax.Request("/post/index.json", {
    parameters: {
      tags: "id:" + post_id,
      api_version: 2,
      filter: 1,
      include_tags: "1",
      include_votes: "1",
      include_pools: 1
    },
    method: "get",

    onCreate: function(resp) {
      this.current_ajax_request = resp.request;
    }.bind(this),

    onSuccess: function(resp) {
      if(this.current_ajax_request != resp.request)
        return;

      /* If no posts were returned, then the post ID we're looking up doesn't exist;
       * treat this as a failure. */
      var resp = resp.responseJSON;
      this.success = resp.posts.length > 0;
      if(!this.success)
      {
        notice("Post #" + post_id + " doesn't exist");
        return;
      }

      Post.register_resp(resp);
    }.bind(this),

    onComplete: function(resp) {
      if(this.current_ajax_request == resp.request)
        this.current_ajax_request = null;

      /* If the request failed and we were requesting wanted_post_id, don't keep trying. */
      var success = resp.request.success() && this.success;
      if(!success && post_id == this.wanted_post_id)
      {
        /* As a special case, if the post we requested doesn't exist and we aren't displaying
         * anything at all, force the thumb bar open so we don't show nothing at all. */
        if(this.displayed_post_id == null)
          document.fire("viewer:set-thumb-bar", {set: true});

        return;
      }

      /* This will either load the post we just finished, or request data for the
       * one we want. */
      this.set_post(this.wanted_post_id, this.wanted_post_frame);
    }.bind(this),

    onFailure: function(resp) {
      notice("Error " + resp.status + " loading post");
    }.bind(this)
  });
}

BrowserView.prototype.set_viewing_larger_version = function(b)
{
  this.viewing_larger_version = b;

  var post = Post.posts.get(this.displayed_post_id);
  var can_zoom = post != null && post.jpeg_url != post.sample_url;
  this.container.down(".zoom-icon-none").show(!can_zoom);
  this.container.down(".zoom-icon-in").show(can_zoom && !this.viewing_larger_version);
  this.container.down(".zoom-icon-out").show(can_zoom && this.viewing_larger_version);

  /* When we're on the regular version and we're on a touchscreen, disable drag
   * scrolling so we can use it to switch images instead. */
  if(Prototype.BrowserFeatures.Touchscreen && this.image_dragger)
    this.image_dragger.set_disabled(!b);

  /* Only allow dragging to create new frames when not viewing the large version,
   * since we need to be able to drag the image. */
  if(this.frame_editor)
  {
    this.frame_editor.set_drag_to_create(!b);
    this.frame_editor.set_show_corner_drag(!b);
  }
}

BrowserView.prototype.set_main_image = function(post, post_frame)
{
  /*
   * Clear the previous post, if any.  Don't keep the old IMG around; create a new one, or
   * we may trigger long-standing memory leaks in WebKit, eg.:
   * https://bugs.webkit.org/show_bug.cgi?id=31253
   *
   * This also helps us avoid briefly displaying the old image with the new dimensions, which
   * can otherwise take some hoop jumping to prevent.
   */
  if(this.img != null)
  {
    this.img.stopObserving();
    this.img.parentNode.removeChild(this.img);
    this.image_pool.release(this.img);
    this.img = null;
  }

  /* If this post is blacklisted, show a message instead of displaying it. */
  var hide_post = Post.is_blacklisted(post.id) && post.id != this.blacklist_override_post_id;
  this.container.down(".blacklisted-message").show(hide_post);
  if(hide_post)
    return;

  this.img = this.image_pool.get();
  this.img.className = "main-image";

  if(this.canvas)
    this.canvas.hide();
  this.img.show();

  /*
   * Work around an iPhone bug.  If a touchstart event is sent to this.img, and then
   * (due to a swipe gesture) we remove the image and replace it with a new one, no
   * touchend is ever delivered, even though it's the containing box listening to the
   * event.  Work around this by setting the image to pointer-events: none, so clicks on
   * the image will actually be sent to the containing box directly.
   */
  this.img.setStyle({pointerEvents: "none"});

  this.img.on("load", this.image_loaded_event.bindAsEventListener(this));

  this.img.fully_loaded = false;
  if(post_frame != -1 && post_frame < post.frames.length)
  {
    var frame = post.frames[post_frame];
    this.img.src = frame.url;
    this.img_box.original_width = frame.width;
    this.img_box.original_height = frame.height;
    this.img_box.show();
  }
  else if(this.viewing_larger_version && post.jpeg_url)
  {
    this.img.src = post.jpeg_url;
    this.img_box.original_width = post.jpeg_width;
    this.img_box.original_height = post.jpeg_height;
    this.img_box.show();
  }
  else if(!this.viewing_larger_version && post.sample_url)
  {
    this.img.src = post.sample_url;
    this.img_box.original_width = post.sample_width;
    this.img_box.original_height = post.sample_height;
    this.img_box.show();
  }
  else
  {
    /* Having no sample URL is an edge case, usually from deleted posts.  Keep the number
     * of code paths smaller by creating the IMG anyway, but not showing it. */
    this.img_box.hide();
  }

  this.container.down(".image-box").appendChild(this.img);

  if(this.viewing_larger_version)
  {
    this.navigator.set_image(post.preview_url, post.actual_preview_width, post.actual_preview_height);
    this.navigator.set_autohide(!this.post_ui_visible);
  }
  this.navigator.enable(this.viewing_larger_version);

  this.scale_and_position_image();
}

/*
 * Display post_id.  If post_frame is not null, set the specified frame.
 *
 * If no_hash_change is true, the UrlHash will not be updated to reflect the new post.
 * This should be used when this is called to load the post already reflected by the
 * URL hash.  For example, the hash "#/pool:123" shows pool 123 in the thumbnails and
 * shows its first post in the view.  It should *not* change the URL hash to reflect
 * the actual first post (eg. #12345/pool:123).  This will insert an unwanted history
 * state in the browser, so the user has to go back twice to get out.
 *
 * no_hash_change should also be set when loading a state as a result of hashchange,
 * for similar reasons.
 */
BrowserView.prototype.set_post = function(post_id, post_frame, lazy, no_hash_change, replace_history)
{
  if(post_id == null)
    throw "post_id must not be null";

  /* If there was a lazy load pending, cancel it. */
  this.cancel_lazily_load();

  this.wanted_post_id = post_id;
  this.wanted_post_frame = post_frame;
  this.wanted_post_no_hash_change = no_hash_change;
  this.wanted_post_replace_history = replace_history;

  if(post_id == this.displayed_post_id && post_frame == this.displayed_post_frame)
    return;

  /* If a lazy load was requested and we're not yet loading the image for this post,
   * delay loading. */
  var is_cached = this.last_preload_request_active && this.post_frame_list_includes(this.last_preload_request, post_id, post_frame);
  if(lazy && !is_cached)
  {
    this.lazy_load_timer = window.setTimeout(function() {
      this.lazy_load_timer = null;
      this.set_post(this.wanted_post_id, this.wanted_post_frame, false, this.wanted_post_no_hash_change, this.wanted_post_replace_history);
    }.bind(this), 500);
    return;
  }

  this.hide_frame_editor();

  var post = Post.posts.get(post_id);
  if(post == null)
  {
    /* The post we've been asked to display isn't loaded.  Request a load and come back. */
    if(this.displayed_post_id == null)
      this.container.down(".post-info").hide();

    this.load_post_id_data(post_id);
    return;
  }

  if(post_frame == null) {
    // If post_frame is unspecified and we have a frame, display the first.
    post_frame = this.get_default_post_frame(post_id);

    // We know what frame we actually want to display now, so update wanted_post_frame.
    this.wanted_post_frame = post_frame;
  }

  /* If post_frame doesn't exist, just display the main post. */
  if(post_frame != -1 && post.frames.length <= post_frame)
    post_frame = -1;

  this.displayed_post_id = post_id;
  this.displayed_post_frame = post_frame;
  if(!no_hash_change) {
    var post_frame_hash = this.get_post_frame_hash(post, post_frame);
    UrlHash.set_deferred({"post-id": post_id, "post-frame": post_frame_hash}, replace_history);
  }

  this.set_viewing_larger_version(false);

  this.set_main_image(post, post_frame);

  if(this.vote_widget)
    this.vote_widget.set_post_id(post.id);
  if(this.popup_vote_widget)
    this.popup_vote_widget.set_post_id(post.id);

  document.fire("viewer:displayed-post-changed", { post_id: post_id, post_frame: post_frame });

  this.set_post_info();

  /* Hide the editor when changing posts. */
  this.edit_show(false);
}

/* Return the frame spec for the hash, eg. "-0".
 *
 * If the post has no frames, then just omit the frame spec.  If the post has any frames,
 * then return the frame number or "-F" for the full image. */
BrowserView.prototype.post_frame_hash = function(post, post_frame)
{
  if(post.frames.length == 0)
    return "";
  return "-" + (post_frame == -1? "F":post_frame);
}

/* Return the default frame to display for the given post.  If the post isn't loaded,
 * we don't know which frame we'll display and null will be returned.  This corresponds
 * to a hash of #1234, where no frame is specified (eg. #1234-F, #1234-0). */
BrowserView.prototype.get_default_post_frame = function(post_id)
{
  var post = Post.posts.get(post_id);
  if(post == null)
    return null;
  
  return post.frames.length > 0? 0: -1;
}

BrowserView.prototype.get_post_frame_hash = function(post, post_frame)
{
/* 
 * Omitting the frame in the hash selects the default frame: the first frame if any,
 * otherwise the full image.  If we're setting the hash to a post_frame which would be
 * selected by this default, omit the frame so this default is used.  For example, if
 * post #1234 has one frame and post_frame is 0, it would be selected by the default,
 * so omit the frame and use a hash of #1234, not #1234-0.
 *
 * This helps normalize the hash.  Otherwise, loading /#1234 will update the hash to
 * /#1234-in set_post, causing an unwanted history entry.
 */
  var default_frame = post.frames.length > 0? 0:-1;
  if(post_frame == default_frame)
    return null;
  else
    return post_frame;
}
/* Set the post info box for the currently displayed post. */
BrowserView.prototype.set_post_info = function()
{
  var post = Post.posts.get(this.displayed_post_id);
  if(!post)
    return;

  this.container.down(".post-id").setTextContent(post.id);
  this.container.down(".post-id-link").href = "/post/show/" + post.id;
  this.container.down(".posted-by").show(post.creator_id != null);
  this.container.down(".posted-at").setTextContent(time_ago_in_words(new Date(post.created_at*1000)));

  /* Fill in the pool list. */
  var pool_info = this.container.down(".pool-info");
  while(pool_info.firstChild)
    pool_info.removeChild(pool_info.firstChild);
  if(post.pool_posts)
  {
    post.pool_posts.each(function(pp) {
      var pool_post = pp[1];
      var pool_id = pool_post.pool_id;
      var pool = Pool.pools.get(pool_id);

      var pool_title = pool.name.replace(/_/g, " ");
      var sequence = pool_post.sequence;
      if(sequence.match(/^[0-9]/))
        sequence = "#" + sequence;

      var html = 
        '<div class="pool-info">Post ${sequence} in <a class="pool-link" href="/post/browse#/pool:${pool_id}">${desc}</a> ' +
        '(<a target="_blank" href="/pool/show/${pool_id}">pool page</a>)';

      if(Pool.can_edit_pool(pool))
        html += '<span class="advanced-editing"> (<a href="#" class="remove-pool-from-post">remove</a>)</div></span>';

      var div = html.subst({
        sequence: sequence,
        pool_id: pool_id,
        desc: pool_title.escapeHTML()
      }).createElement();

      div.post_id = post.id;
      div.pool_id = pool_id;

      pool_info.appendChild(div);
    }.bind(this));
  }

  if(post.creator_id != null)
  {
    this.container.down(".posted-by").down("A").href = "/user/show/" + post.creator_id;
    this.container.down(".posted-by").down("A").setTextContent(post.author);
  }

  this.container.down(".post-dimensions").setTextContent(post.width + "x" + post.height);
  this.container.down(".post-source").show(post.source != "");
  if(post.source != "")
  {
    var text = post.source;
    var url = null;

    var m = post.source.match(/^http:\/\/.*pixiv\.net\/img\/(\w+)\/(\d+)\.\w+$/);
    if(m)
    {
      text = "pixiv #" + m[2] + " (" + m[1] + ")";
      url = "http://www.pixiv.net/member_illust.php?mode=medium&illust_id=" + m[2];
    }
    else if(post.source.substr(0, 7) == "http://")
    {
      text = text.substr(7);
      if(text.substr(0, 4) == "www.")
        text = text.substr(4);
      if(text.length > 20)
        text = text.substr(0, 20) + "...";
      url = post.source;
    }

    var source_box = this.container.down(".post-source");

    source_box.down("A").show(url != null);
    source_box.down("SPAN").show(url == null);
    if(url)
    {
      source_box.down("A").href = url;
      source_box.down("A").setTextContent(text);
    }
    else
    {
      source_box.down("SPAN").setTextContent(text);
    }

  }

  if(post.frames.length > 0)
  {
    /* Hide this with a class rather than by changing display, so show_frame_editor
     * and hide_frame_editor can hide and unhide this separately. */
    this.container.down(".post-frames").removeClassName("no-frames");

    var frame_list = this.container.down(".post-frame-list");
    while(frame_list.firstChild)
      frame_list.removeChild(frame_list.firstChild);

    for(var i = -1; i < post.frames.length; ++i)
    {
      var text = i == -1? "main": (i+1);

      var a = document.createElement("a");
      a.href = "/post/browse#" + post.id  + this.post_frame_hash(post, i);

      a.className = "post-frame-link";
      if(this.displayed_post_frame == i)
        a.className += " current-post-frame";

      a.setTextContent(text);
      a.post_frame = i;
      frame_list.appendChild(a);
    }
  }
  else
  {
    this.container.down(".post-frames").addClassName("no-frames");
  }


  var ratings = {s: "Safe", q: "Questionable", e: "Explicit"};
  this.container.down(".post-rating").setTextContent(ratings[post.rating]);
  this.container.down(".post-score").setTextContent(post.score);
  this.container.down(".post-hidden").show(!post.is_shown_in_index);

  this.container.down(".post-info").show(this.post_ui_visible);

  var file_extension = function(path)
  {
    var m = path.match(/.*\.([^.]+)/);
    if(!m)
      return "";
    return m[1];
  }

  var has_sample = (post.sample_url != post.file_url);
  var has_jpeg = (post.jpeg_url != post.file_url);
  var has_image = post.file_url != null && !has_sample;

  /* Hide the whole download-links box if there are no downloads available, usually
   * because of a deleted post. */
  this.container.down(".download-links").show(has_image || has_sample || has_jpeg);

  this.container.down(".download-image").show(has_image);
  if(has_image)
  {
    this.container.down(".download-image").href = post.file_url;
    this.container.down(".download-image-desc").setTextContent(number_to_human_size(post.file_size) + " " + file_extension(post.file_url.toUpperCase()));
  }

  this.container.down(".download-jpeg").show(has_sample);
  if(has_sample)
  {
    this.container.down(".download-jpeg").href = has_jpeg? post.jpeg_url: post.file_url;
    var image_desc = number_to_human_size(has_jpeg? post.jpeg_file_size: post.file_size) /*+ " " + post.jpeg_width + "x" + post.jpeg_height*/ + " JPG";
    this.container.down(".download-jpeg-desc").setTextContent(image_desc);
  }

  this.container.down(".download-png").show(has_jpeg);
  if(has_jpeg)
  {
    this.container.down(".download-png").href = post.file_url;
    var png_desc = number_to_human_size(post.file_size) /*+ " " + post.width + "x" + post.height*/ + " " + file_extension(post.file_url.toUpperCase());
    this.container.down(".download-png-desc").setTextContent(png_desc);
  }

  /* For links that are handled by click events, try to set the href so that copying the
   * link will give a similar effect.  For example, clicking parent-post will call set_post
   * to display it, and the href links to /post/browse#12345. */
  var parent_post = this.container.down(".parent-post");
  parent_post.show(post.parent_id != null);
  if(post.parent_id)
    parent_post.down("A").href = "/post/browse#" + post.parent_id;

  var child_posts = this.container.down(".child-posts");
  child_posts.show(post.has_children);
  if(post.has_children)
    child_posts.down("A").href = "/post/browse#/parent:" + post.id;


  /* Create the tag links. */
  var tag_span = this.container.down(".post-tags");
  var first = true;
  while(tag_span.firstChild)
    tag_span.removeChild(tag_span.firstChild);


  var tags_by_type = Post.get_post_tags_with_type(post);
  tags_by_type.each(function(t) {
      var tag = t[0];
      var type = t[1];

      var span = $(document.createElement("SPAN", ""));
      span = $(span);
      span.className = "tag-type-" + type;

      var space = document.createTextNode(" ");
      span.appendChild(space);

      var a = $(document.createElement("A", ""));
      a.href = "/post/browse#/" + window.encodeURIComponent(tag);
      a.tag_name = tag;
      a.className = "post-tag tag-type-" + type;

      /* Break tags with zero-width spaces, so long tags can be wrapped. */
      var tag_with_breaks = tag.replace(/_/g, "_\u200B");
      a.setTextContent(tag_with_breaks);
      span.appendChild(a);
      tag_span.appendChild(span);
  });

  var flag_post = this.container.down(".flag-button");
  flag_post.show(post.status == "active");

  this.container.down(".post-approve").show(post.status == "flagged" || post.status == "pending");
  this.container.down(".post-delete").show(post.status != "deleted");
  this.container.down(".post-undelete").show(post.status == "deleted");

  var flagged = this.container.down(".flagged-info");
  flagged.show(post.status == "flagged");
  if(post.status == "flagged" && post.flag_detail)
  {
    var by = flagged.down(".by");
    flagged.down(".flagged-by-box").show(post.flag_detail.user_id != null);
    if(post.flag_detail.user_id != null)
    {
      by.setTextContent(post.flag_detail.flagged_by);
      by.href = "/user/show/" + post.flag_detail.user_id;
    }

    var reason = flagged.down(".reason");
    reason.setTextContent(post.flag_detail.reason);
  }

  /* Moderators can unflag images, and the person who flags an image can unflag it himself. */
  var is_flagger = post.flag_detail && post.flag_detail.user_id == User.get_current_user_id();
  var can_unflag = flagged && (User.is_mod_or_higher() || is_flagger);
  flagged.down(".post-unflag").show(can_unflag);

  var pending = this.container.down(".status-pending");
  pending.show(post.status == "pending");
  this.container.down(".pending-reason-box").show(post.flag_detail && post.flag_detail.reason);
  if(post.flag_detail)
    this.container.down(".pending-reason").setTextContent(post.flag_detail.reason);

  var deleted = this.container.down(".status-deleted");
  deleted.show(post.status == "deleted");
  if(post.status == "deleted")
  {
    var by_container = deleted.down(".by-container");
    by_container.show(post.flag_detail.flagged_by != null);

    var by = by_container.down(".by");
    by.setTextContent(post.flag_detail.flagged_by);
    by.href = "/user/show/" + post.flag_detail.user_id;

    var reason = deleted.down(".reason");
    reason.setTextContent(post.flag_detail.reason);
  }

  this.container.down(".status-held").show(post.is_held);
  var has_permission = User.get_current_user_id() == post.creator_id || User.is_mod_or_higher();
  this.container.down(".activate-post").show(has_permission);
}

BrowserView.prototype.edit_show = function(shown)
{
  var post = Post.posts.get(this.displayed_post_id);
  if(!post)
    shown = false;

  if(!User.is_member_or_higher())
    shown = false;

  this.edit_shown = shown;
  this.container.down(".post-tags-box").show(!shown);
  this.container.down(".post-edit").show(shown);
  if(!shown)
  {
    /* Revert all changes. */
    this.frame_editor.discard();
    return;
  }

  this.select_edit_box(".post-edit-main");

  /* This returns [tag, tag type].  We only want the tag; we call this so we sort the
   * tags consistently. */
  var tags_by_type = Post.get_post_tags_with_type(post);
  var tags = tags_by_type.pluck(0);

  tags = tags.join(" ") + " ";

  this.container.down(".edit-tags").old_value = tags;
  this.container.down(".edit-tags").value = tags;
  this.container.down(".edit-source").value = post.source;
  this.container.down(".edit-parent").value = post.parent_id;
  this.container.down(".edit-shown-in-index").checked = post.is_shown_in_index;

  var rating_class = new Hash({ s: ".edit-safe", q: ".edit-questionable", e: ".edit-explicit" });
  this.container.down(rating_class.get(post.rating)).checked = true;

  this.edit_post_area_changed();

  this.container.down(".edit-tags").focus();
}

/* Set the size of the tag edit area to the size of its contents. */
BrowserView.prototype.edit_post_area_changed = function()
{
  var post_edit = this.container.down(".post-edit");
  var element = post_edit.down(".edit-tags");
  element.style.height = "0px";
  element.style.height = element.scrollHeight + "px";
if(0)
{
  var rating = null;
  var source = null;
  var parent_id = null;
  element.value.split(" ").each(function(tag)
  {
    /* This mimics what the server side does; it does prevent metatags from using
     * uppercase in source: metatags. */
    tag = tag.toLowerCase();
    /* rating:q or just q: */
    var m = tag.match(/^(rating:)?([qse])$/);
    if(m)
    {
      rating = m[2];
      return;
    }

    var m = tag.match(/^(parent):([0-9]+)$/);
    if(m)
    {
      if(m[1] == "parent")
        parent_id = m[2];
    }

    var m = tag.match(/^(source):(.*)$/);
    if(m)
    {
      if(m[1] == "source")
        source = m[2];
    }
  }.bind(this));

  debug("rating: " + rating);
  debug("source: " + source);
  debug("parent: " + parent_id);
}
}

BrowserView.prototype.edit_save = function()
{
  var save_completed = function()
  {
    notice("Post saved");

    /* If we're still showing the post we saved, hide the edit area. */
    if(this.displayed_post_id == post_id)
      this.edit_show(false);
  }.bind(this);
  var post_id = this.displayed_post_id;
  
  /* If we're in the frame editor, save it.  Don't save the hidden main editor. */
  if(this.frame_editor)
  {
    if(this.frame_editor.is_opened())
    {
      this.frame_editor.save(save_completed);
      return;
    }
  }

  var edit_tags = this.container.down(".edit-tags");
  var tags = edit_tags.value;

  /* Opera doesn't blur the field automatically, even when we hide it later. */
  edit_tags.blur();

  /* Find which rating is selected. */
  var rating_class = new Hash({ s: ".edit-safe", q: ".edit-questionable", e: ".edit-explicit" });
  var selected_rating = "s";
  rating_class.each(function(c) {
    if(this.container.down(c[1]).checked)
      selected_rating = c[0];
  }.bind(this));

  /* update_batch will give us updates for any related posts, as well as the one we're
   * updating. */
  Post.update_batch([{
    id: post_id,
    tags: this.container.down(".edit-tags").value,
    old_tags: this.container.down(".edit-tags").old_value,
    source: this.container.down(".edit-source").value,
    parent_id: this.container.down(".edit-parent").value,
    is_shown_in_index: this.container.down(".edit-shown-in-index").checked,
    rating: selected_rating
  }], save_completed);
}

BrowserView.prototype.window_resize_event = function(e)
{
  if(e.stopped)
    return;
  this.update_image_window_size();
  this.scale_and_position_image(true);
}

BrowserView.prototype.toggle_view_large_image = function()
{
  var post = Post.posts.get(this.displayed_post_id);
  if(post == null)
    return;
  if(this.img == null)
    return;

  if(post.jpeg_url == post.sample_url)
  {
    /* There's no larger version to display. */
    return;
  }

  /* Toggle between the sample and JPEG version. */
  this.set_viewing_larger_version(!this.viewing_larger_version);
  this.set_main_image(post); // XXX frame
}

/* this.image_window_size is the size of the area where the image is visible. */
BrowserView.prototype.update_image_window_size = function()
{
  this.image_window_size = getWindowSize();

  /* If the thumb bar is shown, exclude it from the window height and fit the image
   * in the remainder.  Since the bar is at the bottom, we don't need to do anything to
   * adjust the top. */
  this.image_window_size.height -= this.thumb_bar_height;

  this.image_window_size.height = Math.max(this.image_window_size.height, 0); /* clamp to 0 if there's no space */

  /* When the window size changes, update the navigator since the cursor will resize to
   * match. */
  this.update_navigator();
}

BrowserView.prototype.scale_and_position_image = function(resizing)
{
  var img_box = this.img_box;
  if(!this.img)
    return;
  var original_width = img_box.original_width;
  var original_height = img_box.original_height;

  var post = Post.posts.get(this.displayed_post_id);
  if(!post)
  {
    debug("unexpected: displayed post " + this.displayed_post_id + " unknown");
    return;
  }

  var window_size = this.image_window_size;

  var ratio = 1.0;
  if(!this.viewing_larger_version)
  {
    /* Zoom the image to fit the viewport. */
    var ratio = window_size.width / original_width;
    if (original_height * ratio > window_size.height)
      ratio = window_size.height / original_height;
  }

  ratio *= Math.pow(0.9, this.zoom_level);

  this.displayed_image_width = Math.round(original_width * ratio);
  this.displayed_image_height = Math.round(original_height * ratio);

  this.img.width = this.displayed_image_width;
  this.img.height = this.displayed_image_height;

  this.update_canvas();

  if(this.frame_editor)
    this.frame_editor.set_image_dimensions(this.displayed_image_width, this.displayed_image_height);

  /* If we're resizing and showing the full-size image, don't snap the position
   * back to the default. */
  if(resizing && this.viewing_larger_version)
    return;

  var x = 0.5;
  var y = 0.5;
  if(this.viewing_larger_version)
  {
    /* Align the image to the top of the screen. */
    y = this.image_window_size.height/2;
    y /= this.displayed_image_height;
  }

  this.center_image_on(x, y);
}

/* x and y are [0,1]. */
BrowserView.prototype.update_navigator = function()
{
  if(!this.navigator)
    return;
  if(!this.img)
    return;

  /* The coordinates of the image located at the top-left corner of the window: */
  var scroll_x = -this.img_box.offsetLeft;
  var scroll_y = -this.img_box.offsetTop;

  /* The coordinates at the center of the window: */
  x = scroll_x + this.image_window_size.width/2;
  y = scroll_y + this.image_window_size.height/2;

  var percent_x = x / this.displayed_image_width;
  var percent_y = y / this.displayed_image_height;

  var height_percent = this.image_window_size.height / this.displayed_image_height;
  var width_percent = this.image_window_size.width / this.displayed_image_width;
  this.navigator.image_position_changed(percent_x, percent_y, height_percent, width_percent);
}

/*
 * If Canvas support is available, we can accelerate drawing.
 *
 * Most browsers are slow when resizing large images.  In the best cases, it results in
 * dragging the image around not being smooth (all browsers except Chrome).  In the worst
 * case it causes rendering the page to be very slow; in Chrome, drawing the thumbnail
 * strip under a large resized image is unusably slow.
 *
 * If Canvas support is enabled, then once the image is fully loaded, blit the image into
 * the canvas at the size we actually want to display it at.  This avoids most scaling
 * performance issues, because it's not rescaling the image constantly while dragging it
 * around.
 *
 * Note that if Chrome fixes its slow rendering of boxes *over* the image, then this may
 * be unnecessary for that browser.  Rendering the image itself is very smooth; Chrome seems
 * to prescale the image just once, which is what we're doing.
 *
 * Limitations:
 * - If full-page zooming is being used, it'll still scale at runtime.
 * - We blit the entire image at once.  It's more efficient to blit parts of the image
 *   as necessary to paint, but that's a lot more work.
 * - Canvas won't blit partially-loaded images, so we do nothing until the image is complete.
 */
BrowserView.prototype.update_canvas = function()
{
  if(!this.img.fully_loaded)
  {
    debug("image incomplete; can't render to canvas");
    return false;
  }

  if(!this.canvas)
    return;

  /* If the contents havn't changed, skip the blit.  This happens frequently when resizing
   * the window when not fitting the image to the screen. */
  if(this.canvas.rendered_url == this.img.src &&
      this.canvas.width == this.displayed_image_width &&
      this.canvas.height == this.displayed_image_height)
  {
    // debug(this.canvas.rendered_url + ", " + this.canvas.width + ", " + this.canvas.height)
    // debug("Skipping canvas blit");
    return;
  }

  this.canvas.rendered_url = this.img.src;
  this.canvas.width = this.displayed_image_width;
  this.canvas.height = this.displayed_image_height;
  var ctx = this.canvas.getContext("2d");
  ctx.drawImage(this.img, 0, 0, this.displayed_image_width, this.displayed_image_height);
  this.canvas.show();
  this.img.hide();

  return true;
}


BrowserView.prototype.center_image_on = function(percent_x, percent_y)
{
  var x = percent_x * this.displayed_image_width;
  var y = percent_y * this.displayed_image_height;

  var scroll_x = x - this.image_window_size.width/2;
  scroll_x = Math.round(scroll_x);

  var scroll_y = y - this.image_window_size.height/2;
  scroll_y = Math.round(scroll_y);

  this.img_box.setStyle({left: -scroll_x + "px", top: -scroll_y + "px"});

  this.update_navigator();
}

BrowserView.prototype.cancel_lazily_load = function()
{
  if(this.lazy_load_timer == null)
    return;

   window.clearTimeout(this.lazy_load_timer);
   this.lazy_load_timer = null;
}

/* Update the window title when the display changes. */
WindowTitleHandler = function()
{
  this.searched_tags = "";
  this.post_id = null;
  this.post_frame = null;
  this.pool = null;

  document.on("viewer:searched-tags-changed", function(e) {
    this.searched_tags = e.memo.tags || "";
    this.update();
  }.bindAsEventListener(this));

  document.on("viewer:displayed-post-changed", function(e) {
    this.post_id = e.memo.post_id;
    this.post_frame = e.memo.post_id;
    this.update();
  }.bindAsEventListener(this));

  document.on("viewer:displayed-pool-changed", function(e) {
    this.pool = e.memo.pool;
    this.update();
  }.bindAsEventListener(this));

  this.update();
}

WindowTitleHandler.prototype.update = function()
{
  var post = Post.posts.get(this.post_id);

  if(this.pool)
  {
    var title = this.pool.name.replace(/_/g, " ");

    if(post && post.pool_posts)
    {
      var pool_post = post.pool_posts.get(this.pool.id);
      if(pool_post)
      {
        var sequence = pool_post.sequence;
        title += " ";
        if(sequence.match(/^[0-9]/))
          title += "#";
        title += sequence;
      }
    }
  }
  else
  {
    var title = "/" + this.searched_tags.replace(/_/g, " ");
  }

  title += " - Browse";
  document.title = title;
}

BrowserView.prototype.parent_post_click_event = function(event)
{
  event.stop();

  var post = Post.posts.get(this.displayed_post_id);
  if(post == null || post.parent_id == null)
    return;

  this.set_post(post.parent_id);
}

BrowserView.prototype.child_posts_click_event = function(event)
{
  event.stop();

  /* Search for this post's children.  Set the results mode to center-on-current, so we
   * focus on the current item. */
  document.fire("viewer:perform-search", {
    tags: "parent:" + this.displayed_post_id,
    results_mode: "center-on-current"
  });
}

BrowserView.prototype.select_edit_box = function(className)
{
  if(this.shown_edit_container)
    this.shown_edit_container.hide();
  this.shown_edit_container = this.container.down(className);
  this.shown_edit_container.show();
}

BrowserView.prototype.show_frame_editor = function()
{
  this.select_edit_box(".frame-editor");

  /* If we're displaying a frame and not the whole image, switch to the main image. */
  var post_frame = null;
  if(this.displayed_post_frame != -1)
  {
    post_frame = this.displayed_post_frame;
    document.fire("viewer:set-active-post", {post_id: this.displayed_post_id, post_frame: -1});
  }

  this.frame_editor.open(this.displayed_post_id);
  this.container.down(".post-frames").hide();

  /* If we were on a frame when opened, focus the frame we were on.  Otherwise,
   * leave it on the default. */
  if(post_frame != null)
    this.frame_editor.focus(post_frame);
}

BrowserView.prototype.hide_frame_editor = function()
{
  this.frame_editor.discard();
  this.container.down(".post-frames").show();
}

var Navigator = function(container, target)
{
  this.container = container;
  this.target = target;
  this.hovering = false;
  this.autohide = false;
  this.img = this.container.down(".image-navigator-img");
  this.container.show();

  this.handlers = [];
  this.handlers.push(this.container.on("mousedown", this.mousedown_event.bindAsEventListener(this)));
  this.handlers.push(this.container.on("mouseover", this.mouseover_event.bindAsEventListener(this)));
  this.handlers.push(this.container.on("mouseout", this.mouseout_event.bindAsEventListener(this)));

  this.dragger = new DragElement(this.container, {
    snap_pixels: 0,
    onenddrag: this.enddrag.bind(this),
    ondrag: this.ondrag.bind(this)
  });
}

Navigator.prototype.set_image = function(image_url, width, height)
{
  this.img.src = image_url;
  this.img.width = width;
  this.img.height = height;
}

Navigator.prototype.enable = function(enabled)
{
  this.container.show(enabled);
}

Navigator.prototype.mouseover_event = function(e)
{
  if(e.relatedTarget && e.relatedTarget.isParentNode(this.container))
    return;
  debug("over " + e.target.className + ", " + this.container.className + ", " + e.target.isParentNode(this.container));
  this.hovering = true;
  this.update_visibility();
}

Navigator.prototype.mouseout_event = function(e)
{
  if(e.relatedTarget && e.relatedTarget.isParentNode(this.container))
    return;
  debug("out " + e.target.className);
  this.hovering = false;
  this.update_visibility();
}

Navigator.prototype.mousedown_event = function(e)
{
  var x = e.pointerX();
  var y = e.pointerY();
  var coords = this.get_normalized_coords(x, y);
  this.center_on_position(coords);
}

Navigator.prototype.enddrag = function(e)
{
  this.shift_lock_anchor = null;
  this.locked_to_x = null;
  this.update_visibility();
}

Navigator.prototype.ondrag = function(e)
{
  var coords = this.get_normalized_coords(e.x, e.y);
  if(e.latest_event.shiftKey != (this.shift_lock_anchor != null))
  {
    /* The shift key has been pressed or released. */
    if(e.latest_event.shiftKey)
    {
      /* The shift key was just pressed.  Remember the position we were at when it was
       * pressed. */
      this.shift_lock_anchor = [coords[0], coords[1]];
    }
    else
    {
      /* The shift key was released. */
      this.shift_lock_anchor = null;
      this.locked_to_x = null;
    }
  }

  this.center_on_position(coords);
}

Navigator.prototype.image_position_changed = function(percent_x, percent_y, height_percent, width_percent)
{
  /* When the image is moved or the visible area is resized, update the cursor rectangle. */
  var cursor = this.container.down(".navigator-cursor");
  cursor.setStyle({
    top: this.img.height * (percent_y - height_percent/2) + "px",
    left: this.img.width * (percent_x - width_percent/2) + "px",
    width: this.img.width * width_percent + "px",
    height: this.img.height * height_percent + "px"
  });
}

Navigator.prototype.get_normalized_coords = function(x, y)
{
  var offset = this.img.cumulativeOffset();
  x -= offset.left;
  y -= offset.top;
  x /= this.img.width;
  y /= this.img.height;
  return [x, y];

}

/* x and y are absolute window coordinates. */
Navigator.prototype.center_on_position = function(coords)
{
  if(this.shift_lock_anchor)
  {
    if(this.locked_to_x == null)
    {
      /* Only change the coordinate with the greater delta. */
      var change_x = Math.abs(coords[0] - this.shift_lock_anchor[0]);
      var change_y = Math.abs(coords[1] - this.shift_lock_anchor[1]);

      /* Only lock to moving vertically or horizontally after we've moved a small distance
       * from where shift was pressed. */
      if(change_x > 0.1 || change_y > 0.1)
        this.locked_to_x = change_x > change_y;
    }

    /* If we've chosen an axis to lock to, apply it. */
    if(this.locked_to_x != null)
    {
      if(this.locked_to_x)
        coords[1] = this.shift_lock_anchor[1];
      else
        coords[0] = this.shift_lock_anchor[0];
    }
  }

  coords[0] = Math.max(0, Math.min(coords[0], 1));
  coords[1] = Math.max(0, Math.min(coords[1], 1));

  this.target.fire("viewer:center-on", {x: coords[0], y: coords[1]});
}

Navigator.prototype.set_autohide = function(autohide)
{
  this.autohide = autohide;
  this.update_visibility();
}

Navigator.prototype.update_visibility = function()
{
  var box = this.container.down(".image-navigator-box");
  var visible = !this.autohide || this.hovering || this.dragger.dragging;
  box.style.visibility = visible? "visible":"hidden";
}

Navigator.prototype.destroy = function()
{
  this.dragger.destroy();

  this.handlers.each(function(h) { h.stop(); });
  this.dragger = this.handlers = null;

  this.container.hide();
}




// script.aculo.us builder.js v1.8.0, Tue Nov 06 15:01:40 +0300 2007

// Copyright (c) 2005-2007 Thomas Fuchs (http://script.aculo.us, http://mir.aculo.us)
//
// script.aculo.us is freely distributable under the terms of an MIT-style license.
// For details, see the script.aculo.us web site: http://script.aculo.us/

var Builder = {
  NODEMAP: {
    AREA: 'map',
    CAPTION: 'table',
    COL: 'table',
    COLGROUP: 'table',
    LEGEND: 'fieldset',
    OPTGROUP: 'select',
    OPTION: 'select',
    PARAM: 'object',
    TBODY: 'table',
    TD: 'table',
    TFOOT: 'table',
    TH: 'table',
    THEAD: 'table',
    TR: 'table'
  },
  // note: For Firefox < 1.5, OPTION and OPTGROUP tags are currently broken,
  //       due to a Firefox bug
  node: function(elementName) {
    elementName = elementName.toUpperCase();
    
    // try innerHTML approach
    var parentTag = this.NODEMAP[elementName] || 'div';
    var parentElement = document.createElement(parentTag);
    try { // prevent IE "feature": http://dev.rubyonrails.org/ticket/2707
      parentElement.innerHTML = "<" + elementName + "></" + elementName + ">";
    } catch(e) {}
    var element = parentElement.firstChild || null;
      
    // see if browser added wrapping tags
    if(element && (element.tagName.toUpperCase() != elementName))
      element = element.getElementsByTagName(elementName)[0];
    
    // fallback to createElement approach
    if(!element) element = document.createElement(elementName);
    
    // abort if nothing could be created
    if(!element) return;

    // attributes (or text)
    if(arguments[1])
      if(this._isStringOrNumber(arguments[1]) ||
        (arguments[1] instanceof Array) ||
        arguments[1].tagName) {
          this._children(element, arguments[1]);
        } else {
          var attrs = this._attributes(arguments[1]);
          if(attrs.length) {
            try { // prevent IE "feature": http://dev.rubyonrails.org/ticket/2707
              parentElement.innerHTML = "<" +elementName + " " +
                attrs + "></" + elementName + ">";
            } catch(e) {}
            element = parentElement.firstChild || null;
            // workaround firefox 1.0.X bug
            if(!element) {
              element = document.createElement(elementName);
              for(attr in arguments[1]) 
                element[attr == 'class' ? 'className' : attr] = arguments[1][attr];
            }
            if(element.tagName.toUpperCase() != elementName)
              element = parentElement.getElementsByTagName(elementName)[0];
          }
        } 

    // text, or array of children
    if(arguments[2])
      this._children(element, arguments[2]);

     return element;
  },
  _text: function(text) {
     return document.createTextNode(text);
  },

  ATTR_MAP: {
    'className': 'class',
    'htmlFor': 'for'
  },

  _attributes: function(attributes) {
    var attrs = [];
    for(attribute in attributes)
      attrs.push((attribute in this.ATTR_MAP ? this.ATTR_MAP[attribute] : attribute) +
          '="' + attributes[attribute].toString().escapeHTML().gsub(/"/,'&quot;') + '"');
    return attrs.join(" ");
  },
  _children: function(element, children) {
    if(children.tagName) {
      element.appendChild(children);
      return;
    }
    if(typeof children=='object') { // array can hold nodes and text
      children.flatten().each( function(e) {
        if(typeof e=='object')
          element.appendChild(e)
        else
          if(Builder._isStringOrNumber(e))
            element.appendChild(Builder._text(e));
      });
    } else
      if(Builder._isStringOrNumber(children))
        element.appendChild(Builder._text(children));
  },
  _isStringOrNumber: function(param) {
    return(typeof param=='string' || typeof param=='number');
  },
  build: function(html) {
    var element = this.node('div');
    $(element).update(html.strip());
    return element.down();
  },
  dump: function(scope) { 
    if(typeof scope != 'object' && typeof scope != 'function') scope = window; //global scope 
  
    var tags = ("A ABBR ACRONYM ADDRESS APPLET AREA B BASE BASEFONT BDO BIG BLOCKQUOTE BODY " +
      "BR BUTTON CAPTION CENTER CITE CODE COL COLGROUP DD DEL DFN DIR DIV DL DT EM FIELDSET " +
      "FONT FORM FRAME FRAMESET H1 H2 H3 H4 H5 H6 HEAD HR HTML I IFRAME IMG INPUT INS ISINDEX "+
      "KBD LABEL LEGEND LI LINK MAP MENU META NOFRAMES NOSCRIPT OBJECT OL OPTGROUP OPTION P "+
      "PARAM PRE Q S SAMP SCRIPT SELECT SMALL SPAN STRIKE STRONG STYLE SUB SUP TABLE TBODY TD "+
      "TEXTAREA TFOOT TH THEAD TITLE TR TT U UL VAR").split(/\s+/);
  
    tags.each( function(tag){ 
      scope[tag] = function() { 
        return Builder.node.apply(Builder, [tag].concat($A(arguments)));  
      } 
    });
  }
}


Comment = {
  spoiler: function(obj) {
    obj = $(obj);
    var text = obj.next(".spoilertext");
    var warning = obj.down(".spoilerwarning");
    obj.hide();
    text.show();
  },

  flag: function(id) {
    if(!confirm("Flag this comment?"))
      return;

    notice("Flagging comment for deletion...")

    new Ajax.Request("/comment/mark_as_spam.json", {
      parameters: {
        "id": id,
        "comment[is_spam]": 1
      },
      onComplete: function(resp) {
        var resp = resp.responseJSON

        if (resp.success) {
          notice("Comment flagged for deletion");
        } else {
          notice("Error: " + resp.reason);
        }
      }
    })
  },
  
  quote: function(id) {
    new Ajax.Request("/comment/show.json", {
      method: "get",
      parameters: {
        "id": id
      },
      onSuccess: function(resp) {
        var resp = resp.responseJSON
        var stripped_body = resp.body.replace(/\[quote\](?:.|\n|\r)+?\[\/quote\](?:\r\n|\r|\n)*/gm, "")
        var body = '[quote]' + resp.creator + ' said:\n' + stripped_body + '\n[/quote]\n\n'
        $('reply-' + resp.post_id).show()
				if ($('respond-link-' + resp.post_id)) {
        	$('respond-link-' + resp.post_id).hide()
				}
        $('reply-text-' + resp.post_id).value += body
      },
      onFailure: function(req) {
        notice("Error quoting comment")
      }
    })
  },
  destroy: function(id) {
    if (!confirm("Are you sure you want to delete this comment?") ) {
      return;
    }

    new Ajax.Request("/comment/destroy.json", {
      parameters: {
        "id": id
      },
      onSuccess: function(resp) {
        document.location.reload()
      },
      onFailure: function(resp) {
        var resp = resp.responseJSON
        notice("Error deleting comment: " + resp.reason)
      }
    })
  },

  show_translated: function(id, translated) {
    var element = $("c" + id);
    element.down(".body").show(translated);
    element.down(".untranslated-body").show(!translated);
    element.down(".show-translated").show(translated);
    element.down(".show-untranslated").show(!translated);
  },

  show_reply_form: function(post_id)
  {
    $("respond-link-" + post_id).hide();
    $("reply-" + post_id).show();
    $("reply-" + post_id).down("textarea").focus();
  }
}


var DANBOORU_VERSION = {
  major: 1,
  minor: 13,
  build: 0
}

/* If initial is true, this is a notice set by the notice cookie and not a
 * realtime notice from user interaction. */
function notice(msg, initial) {
  /* If this is an initial notice, and this screen has a dedicated notice
   * container other than the floating notice, use that and don't disappear
   * it. */
  if(initial) {
    var static_notice = $("static_notice");
    if(static_notice) {
      static_notice.update(msg);
      static_notice.show();
      return;
    }
  }

  start_notice_timer();
  $('notice').update(msg);
  $('notice-container').show();
}

function number_to_human_size(size, precision)
{
  if(precision == null)
    precision = 1;

  size = Number(size);
  if(size.toFixed(0) == 1) text = "1 Byte";
  else if(size < 1024)                  text = size.toFixed(0) + " Bytes";
  else if(size < 1024*1024)             text = (size / 1024).toFixed(precision) + " KB";
  else if(size < 1024*1024*1024)        text = (size / (1024*1024)).toFixed(precision) + " MB";
  else if(size < 1024*1024*1024*1024)   text = (size / (1024*1024*1024)).toFixed(precision) + " GB";
  else                                  text = (size / (1024*1024*1024*1024)).toFixed(precision) + " TB";

  text = text.gsub(/([0-9]\.\d*?)0+ /, '#{1} ' ).gsub(/\. /,' ');
  return text;
}

function time_ago_in_words(from_time, to_time)
{
  if(to_time == null)
    to_time = new Date();

  var from_time = from_time.valueOf();
  var to_time = to_time.valueOf();
  distance_in_seconds = Math.abs((to_time - from_time)/1000).round();
  distance_in_minutes = (distance_in_seconds/60).round();

  if(distance_in_minutes <= 1)
    return "1 minute";

  if(distance_in_minutes <= 44)
    return distance_in_minutes + " minutes";

  if(distance_in_minutes <= 89)
    return "1 hour";

  if(distance_in_minutes <= 1439)
  {
    var hours = distance_in_minutes / 60;
    hours = (hours - 0.5).round(); // round down
    return hours + " hours";
  }

  if(distance_in_minutes <= 2879)
    return "1 day";

  if(distance_in_minutes <= 43199)
  {
    var days = distance_in_minutes / 1440;
    days = (days - 0.5).round(); // round down
    return days + " days";
  }

  if(distance_in_minutes <= 86399)
    return "1 month";

  if(distance_in_minutes <= 525959)
  {
    var months = distance_in_minutes / 43200;
    months = (months - 0.5).round(); // round down
    return months + " months";
  }

  var years = (distance_in_minutes / 525960).toFixed(1);
  return years + " years";
}

scale = function(x, l1, h1, l2, h2)
{
  return ((x - l1) * (h2 - l2) / (h1 - l1) + l2);
}

clamp = function(n, min, max)
{
  return Math.max(Math.min(n, max), min);
}

var ClearNoticeTimer;
function start_notice_timer() {
  if(ClearNoticeTimer)
    window.clearTimeout(ClearNoticeTimer);

  ClearNoticeTimer = window.setTimeout(function() {
		  $('notice-container').hide();
  }, 5000);
}

var ClipRange = Class.create({
  initialize: function(min, max) {
    if (min > max)  {
      throw "paramError"
    }

    this.min = min
    this.max = max
  },

  clip: function(x) {
    if (x < this.min) {
      return this.min
    }
    
    if (x > this.max) {
      return this.max
    }
    
    return x
  }
})

Object.extend(Element, {
  appendChildBase: Element.appendChild,
  appendChild: function(e) {
    this.appendChildBase(e)
    return e
  }
});

Object.extend(Element.Methods, {
  showBase: Element.show,
  show: function(element, visible) {
    if (visible || visible == null)
      return $(element).showBase();
    else
      return $(element).hide();
  },
  setClassName: function(element, className, enabled) {
    if(enabled)
      return $(element).addClassName(className);
    else
      return $(element).removeClassName(className);
  },
  pickClassName: function(element, classNameEnabled, classNameDisabled, enabled) {
    $(element).setClassName(classNameEnabled, enabled);
    $(element).setClassName(classNameDisabled, !enabled);
  },
  isParentNode: function(element, parentNode) {
    while(element) {
      if(element == parentNode)
        return true;
      element = element.parentNode;
    }
    return false;
  },
  setTextContent: function(element, text)
  {
    if(element.innerText != null)
      element.innerText = text;
    else
      element.textContent = text;
    return element;
  },
  recursivelyVisible: function(element)
  {
    while(element != document.documentElement)
    {
      if(!element.visible())
        return false;
      element = element.parentNode;
    }
    return true;
  }
});
Element.addMethods()

var KeysDown = new Hash();

/* Many browsers eat keyup events if focus is lost while the button
 * is pressed. */
document.observe("blur", function(e) { KeysDown = new Hash(); })

function OnKeyCharCode(key, f, element)
{
  if(window.opera)
    return;
  if(!element)
    element = document;
  element.observe("keyup", function(e) {
    if (e.keyCode != key)
      return;
    KeysDown.set(KeysDown[e.keyCode], false);
  });
  element.observe("keypress", function(e) {
    if (e.charCode != key)
      return;
    if (e.shiftKey || e.altKey || e.ctrlKey || e.metaKey)
      return;
    if(KeysDown.get(KeysDown[e.keyCode]))
      return;
    KeysDown.set(KeysDown[e.keyCode], true);

    var target = e.target;
    if(target.tagName == "INPUT" || target.tagName == "TEXTAREA")
      return;

    f(e);
    e.stop();
    e.preventDefault();
  });
}

function OnKey(key, options, press, release)
{
  if(!options)
    options = {};
  var element = options["Element"]
  if(!element)
    element = document;
  if(element == document && window.opera && !options.AlwaysAllowOpera)
    return;

  element.observe("keyup", function(e) {
    if (e.keyCode != key)
      return;
    KeysDown[e.keyCode] = false
    if(release)
      release(e);
  });

  element.observe("keydown", function(e) {
    if (e.keyCode != key)
      return;
    if (e.metaKey)
      return;
    if (e.shiftKey != !!options.shiftKey)
      return;
    if (e.altKey != !!options.altKey)
      return;
    if (e.ctrlKey != !!options.ctrlKey)
      return;
    if (!options.allowRepeat && KeysDown[e.keyCode])
      return;

    KeysDown[e.keyCode] = true
    var target = e.target;
    if(!options.AllowTextAreaFields && target.tagName == "TEXTAREA")
      return;
    if(!options.AllowInputFields && target.tagName == "INPUT")
      return;

    if(press && !press(e))
      return;
    e.stop();
    e.preventDefault();
  });
}

function InitTextAreas()
{
  $$("TEXTAREA").each(function(elem) {
    var form = elem.up("FORM");
    if(!form)
      return;

    if(elem.set_login_handler)
      return;
    elem.set_login_handler = true;

    OnKey(13, { ctrlKey: true, AllowInputFields: true, AllowTextAreaFields: true, Element: elem}, function(f) {
      $(form).simulate_submit();
    });
  });
}

function InitAdvancedEditing()
{
  if(Cookie.get("show_advanced_editing") != "1")
    return;

  $(document.documentElement).removeClassName("hide-advanced-editing");
}

/* When we resume a user submit after logging in, we want to run submit events, as
 * if the submit had happened normally again, but submit() doesn't do this.  Run
 * a submit event manually. */
Element.addMethods("FORM", {
  simulate_submit: function(form)
  {
    form = $(form);

    if(document.createEvent)
    {
      var e = document.createEvent("HTMLEvents");
      e.initEvent("submit", true, true);
      form.dispatchEvent(e);

      if(!e.stopped)
        form.submit();
    }
    else
    {
      if(form.fireEvent("onsubmit"))
        form.submit();
    }
  }
});


Element.addMethods({
  simulate_anchor_click: function(a, ev)
  {
    a = $(a);

    if(document.dispatchEvent)
    {
      if(a.dispatchEvent(ev) && !ev.stopped)
        window.location.href = a.href;
    }
    else
    {
      if(a.fireEvent("onclick", ev))
        window.location.href = a.href;
    }
  }
});


clone_event = function(orig)
{
  if(document.dispatchEvent)
  {
    var e = document.createEvent("MouseEvent");
    e.initMouseEvent(orig.type, orig.canBubble, orig.cancelable, orig.view,
        orig.detail, orig.screenX, orig.screenY, orig.clientX, orig.clientY,
        orig.ctrlKey, orig.altKey, orig.shiftKey, orig.metaKey,
        orig.button, orig.relatedTarget);
    return Event.extend(e);
  }
  else
  {
    var e = document.createEventObject(orig);
    return Event.extend(e);
  }
}

Object.extend(String.prototype, {
  subst: function(subs) {
    var text = this;
    for(var s in subs)
    {
      var r = new RegExp("\\${" + s + "}", "g");
      var to = subs[s];
      if(to == null) to = "";
      text = text.replace(r, to);
    }

    return text;
  },

  createElement: function() {
    var container = document.createElement("div");
    container.innerHTML = this;
    return container.removeChild(container.firstChild);
  }
});

function createElement(type, className, html)
{
  var element = $(document.createElement(type));
  element.className = className;
  element.innerHTML = html;
  return element;
}

/* Prototype calls onSuccess instead of onFailure when the user cancelled the AJAX
 * request.  Fix that with a monkey patch, so we don't have to track changes inside
 * prototype.js. */
Ajax.Request.prototype.successBase = Ajax.Request.prototype.success;
Ajax.Request.prototype.success = function()
{
  try {
    if(this.transport.getAllResponseHeaders() == null)
      return false;
  } catch (e) {
    /* FF throws an exception if we call getAllResponseHeaders on a cancelled request. */
    return false;
  }

  return this.successBase();
}

/* Work around a Prototype bug; it discards exceptions instead of letting them fall back
 * to the browser where they'll be logged. */
Ajax.Responders.register({
  onException: function(request, exception) {
    /* Report the error here; don't wait for onerror to get it, since the exception
     * isn't passed to it so the stack trace is lost.  */
    var data = "";
    if(request.url)
      data += "AJAX URL: " + request.url + "\n";

    try {
      var params = request.parameters;
      for(key in params)
      {
        var text = params[key];
        var length = text.length;
        if(text.length > 1024)
          text = text.slice(0, 1024) + "...";
        data += "Parameter (" + length + "): " + key + "=" + text + "\n";
      }
    } catch(e) {
      data += "Couldn't get response parameters: " + e + "\n";
    }

    try {
      var text = request.transport.responseText;
      var length = text.length;
      if(text.length > 1024)
        text = text.slice(0, 1024) + "...";
      data += "Response (" + length + "): ->" + text + "<-\n";
    } catch(e) {
      data += "Couldn't get response text: " + e + "\n";
    }

    ReportError(null, null, null, exception, data);

    (function() {
      throw exception;
    }).defer();
  }
});

/*
 * In Firefox, exceptions thrown from event handlers tend to get lost.  Sometimes they
 * trigger window.onerror, but not reliably.  Catch exceptions out of event handlers and
 * throw them from a deferred context, so they'll make it up to the browser to be
 * logged.
 *
 * This depends on bindAsEventListener actually only being used for event listeners,
 * since it eats exceptions.
 *
 * Only do this in Firefox; not all browsers preserve the call stack in the exception,
 * so this can lose information if used when it's not needed.
 */
if(Prototype.Browser.Gecko)
Function.prototype.bindAsEventListener = function()
{
  var __method = this, args = $A(arguments), object = args.shift();
  return function(event) {
    try {
      return __method.apply(object, [event || window.event].concat(args));
    } catch(exception) {
      (function() { throw exception; }).defer();
    }
  }
}

window.onerror = function(error, file, line)
{
  ReportError(error, file, line, null);
}

/*
 * Return the values of list starting at idx and moving outwards.
 *
 * sort_array_by_distance([0,1,2,3,4,5,6,7,8,9], 5)
 * [5,4,6,3,7,2,8,1,9,0]
 */
sort_array_by_distance = function(list, idx)
{
  var ret = [];
  ret.push(list[idx]);
  for(var distance = 1; ; ++distance)
  {
    var length = ret.length;
    if(idx-distance >= 0)
      ret.push(list[idx-distance]);
    if(idx+distance < list.length)
      ret.push(list[idx+distance]);
    if(length == ret.length)
      break;
  }

  return ret;
}

/* Return the squared distance between two points. */
distance_squared = function(x1, y1, x2, y2)
{
  return Math.pow(x1 - x2, 2) + Math.pow(y1 - y2, 2);
}

/* Return the size of the window. */
getWindowSize = function()
{
  var size = {};
  if(window.innerWidth != null)
  {
    size.width = window.innerWidth;
    size.height = window.innerHeight;
  }
  else
  {
    /* IE: */
    size.width = document.documentElement.clientWidth;
    size.height = document.documentElement.clientHeight;
  }
  return size;
}

/* If 2d canvases are supported, return one.  Otherwise, return null. */
create_canvas_2d = function()
{
  var canvas = document.createElement("canvas");
  if(canvas.getContext && canvas.getContext("2d"))
    return canvas;
  return null;
}

Prototype.Browser.AndroidWebKit = (navigator.userAgent.indexOf("Android") != -1 && navigator.userAgent.indexOf("WebKit") != -1);

/* Some UI simply doesn't make sense on a touchscreen, and may need to be disabled or changed.
 * It'd be nice if this could be done generically, but this is the best available so far ... */
Prototype.BrowserFeatures.Touchscreen = (function() {
  /* iOS WebKit has window.Touch, a constructor for Touch events. */
  if(window.Touch)
    return true;

  // Mozilla/5.0 (Linux; U; Android 2.2; en-us; sdk Build/FRF91) AppleWebKit/533.1 (KHTML, like Gecko) Version/4.0 Mobile Safari/533.1
  if(navigator.userAgent.indexOf("Mobile Safari/") != -1)
    return true;

  // Mozilla/5.0 (iPhone; U; CPU iPhone OS 4_2 like Mac OS X; en-us) AppleWebKit/533.17.9 (KHTML, like Gecko) Mobile/8C134
  if(navigator.userAgent.indexOf("Mobile/") != -1)
    return true;

  return false;
})();


/* When element is dragged, the document moves around it.  If scroll_element is true, the
 * element should be positioned (eg. position: absolute), and the element itself will be
 * scrolled. */
DragElement = function(element, options)
{
  $(document.body).addClassName("not-dragging");

  this.options = options || {};
  if(this.options.snap_pixels == null)
    this.options.snap_pixels = 10;
  this.ignore_mouse_events_until = null;

  this.mousemove_event = this.mousemove_event.bindAsEventListener(this);
  this.mousedown_event = this.mousedown_event.bindAsEventListener(this);
  this.dragstart_event = this.dragstart_event.bindAsEventListener(this);
  this.mouseup_event = this.mouseup_event.bindAsEventListener(this);
  this.click_event = this.click_event.bindAsEventListener(this);
  this.selectstart_event = this.selectstart_event.bindAsEventListener(this);

  this.touchmove_event = this.touchmove_event.bindAsEventListener(this);
  this.touchstart_event = this.touchstart_event.bindAsEventListener(this);
  this.touchend_event = this.touchend_event.bindAsEventListener(this);

  this.move_timer_update = this.move_timer_update.bind(this);

  this.element = element;
  this.dragging = false;

  this.drag_handlers = [];
  this.handlers = [];

  /*
   * Starting drag on mousedown works in most browsers, but has an annoying side-
   * effect: we need to stop the event to prevent any browser drag operations from
   * happening, and that'll also prevent clicking the element from focusing the
   * window.  Stop the actual drag in dragstart.  We won't get mousedown in
   * Opera, but we don't need to stop it there either.
   *
   * Sometimes drag events can leak through, and attributes like -moz-user-select may
   * be needed to prevent it.
   */
  if(!options.no_mouse)
  {
    this.handlers.push(element.on("mousedown", this.mousedown_event));
    this.handlers.push(element.on("dragstart", this.dragstart_event));
  }

  if(!options.no_touch)
  {
    this.handlers.push(element.on("touchstart", this.touchstart_event));
    this.handlers.push(element.on("touchmove", this.touchmove_event));
  }

  /*
   * We may or may not get a click event after mouseup.  This is a pain: if we get a
   * click event, we need to cancel it if we dragged, but we may not get a click event
   * at all; detecting whether a click event came from the drag or not is difficult.
   * Cancelling mouseup has no effect.  FF, IE7 and Opera still send the click event
   * if their dragstart or mousedown event is cancelled; WebKit doesn't.
   */
  if(!Prototype.Browser.WebKit)
    this.handlers.push(element.on("click", this.click_event));
}

DragElement.prototype.destroy = function()
{
  this.stop_dragging(null, true);
  this.handlers.each(function(h) { h.stop(); });
  this.handlers = [];
}

DragElement.prototype.move_timer_update = function()
{
  this.move_timer = null;

  if(!this.options.ondrag)
    return;

  if(this.last_event_params == null)
    return;

  var last_event_params = this.last_event_params;
  this.last_event_params = null;

  var x = last_event_params.x;
  var y = last_event_params.y;

  var anchored_x = x - this.anchor_x;
  var anchored_y = y - this.anchor_y;

  var relative_x = x - this.last_x;
  var relative_y = y - this.last_y;
  this.last_x = x;
  this.last_y = y;

  if(this.options.ondrag)
    this.options.ondrag({
      dragger: this,
      x: x,
      y: y,
      aX: anchored_x,
      aY: anchored_y,
      dX: relative_x,
      dY: relative_y,
      latest_event: last_event_params.event
    });
}

DragElement.prototype.mousemove_event = function(event)
{
  event.stop();
  
  var scrollLeft = (window.pageXOffset || document.documentElement.scrollLeft || document.body.scrollLeft);
  var scrollTop = (window.pageYOffset || document.documentElement.scrollTop || document.body.scrollTop);

  var x = event.pointerX() - scrollLeft;
  var y = event.pointerY() - scrollTop;
  this.handle_move_event(event, x, y);
}

DragElement.prototype.touchmove_event = function(event)
{
  /* Ignore touches other than the one we started with. */
  var touch = null;
  for(var i = 0; i < event.changedTouches.length; ++i)
  {
    var t = event.changedTouches[i];
    if(t.identifier == this.dragging_touch_identifier)
    {
      touch = t;
      break;
    }
  }
  if(touch == null)
    return;

  event.preventDefault();

  /* If a touch drags over the bottom navigation bar in Safari and is released while outside of
   * the viewport, the touchend event is never sent.  Work around this by cancelling the drag
   * if we get too close to the end.  Don't do this if we're in standalone (web app) mode, since
   * there's no navigation bar. */
  if(!window.navigator.standalone && touch.pageY > window.innerHeight-10)
  {
    debug("Dragged off the bottom");
    this.stop_dragging(event, true);
    return;
  }

  var x = touch.pageX;
  var y = touch.pageY;

  this.handle_move_event(event, x, y);
}

DragElement.prototype.handle_move_event = function(event, x, y)
{
  if(!this.dragging)
    return;

  if(!this.dragged)
  {
    var distance = Math.pow(x - this.anchor_x, 2) + Math.pow(y - this.anchor_y, 2);
    var snap_pixels = this.options.snap_pixels;
    snap_pixels *= snap_pixels;

    if(distance < snap_pixels) // 10 pixels
      return;
  }

  if(!this.dragged)
  {
    if(this.options.onstartdrag)
    {
      /* Call the onstartdrag callback.  If it returns true, cancel the drag. */
      if(this.options.onstartdrag({ handler: this, latest_event: event }))
      {
        this.dragging = false;
        return;
      }
    }

    this.dragged = true;
    
    $(document.body).addClassName(this.overriden_drag_class || "dragging");
    $(document.body).removeClassName("not-dragging");
  }

  this.last_event_params = {
    x: x,
    y: y,
    event: event
  };

  if(this.dragging_by_touch && Prototype.Browser.AndroidWebKit)
  {
    /* Touch events on Android tend to queue up when they come in faster than we
     * can process.  Set a timer, so we discard multiple events in quick succession. */
    if(this.move_timer == null)
      this.move_timer = window.setTimeout(this.move_timer_update, 10);
  }
  else
  {
    this.move_timer_update();
  }
}

DragElement.prototype.mousedown_event = function(event)
{
  if(!event.isLeftClick())
    return;

  /* Check if we're temporarily ignoring mouse events. */
  if(this.ignore_mouse_events_until != null)
  {
    var now = (new Date()).valueOf();
    if(now < this.ignore_mouse_events_until)
      return;

    this.ignore_mouse_events_until = null;
  }
  var scrollLeft = (window.pageXOffset || document.documentElement.scrollLeft || document.body.scrollLeft);
  var scrollTop = (window.pageYOffset || document.documentElement.scrollTop || document.body.scrollTop);
  var x = event.pointerX() - scrollLeft;
  var y = event.pointerY() - scrollTop;

  this.start_dragging(event, false, x, y, 0);
}

DragElement.prototype.touchstart_event = function(event)
{
  /* If we have multiple touches, find the first one that actually refers to us. */
  var touch = null;
  for(var i = 0; i < event.changedTouches.length; ++i)
  {
    var t = event.changedTouches[i];
    if(!t.target.isParentNode(this.element))
      continue;
    touch = t;
    break;
  }
  if(touch == null)
    return;

  var x = touch.pageX;
  var y = touch.pageY;
  
  this.start_dragging(event, true, x, y, touch.identifier);
}

DragElement.prototype.start_dragging = function(event, touch, x, y, touch_identifier)
{
  if(this.dragging_touch_identifier != null)
    return;

  /* If we've been started with a touch event, only listen for touch events.  If we've
   * been started with a mouse event, only listen for mouse events.  We may receive
   * both sets of events, and the anchor coordinates for the two may not be compatible. */
  this.drag_handlers.push(document.on("selectstart", this.selectstart_event));
  this.drag_handlers.push(Element.on(window, "pagehide", this.pagehide_event.bindAsEventListener(this)));
  if(touch)
  {
    this.drag_handlers.push(document.on("touchend", this.touchend_event));
    this.drag_handlers.push(document.on("touchcancel", this.touchend_event));
    this.drag_handlers.push(document.on("touchmove", this.touchmove_event));
  }
  else
  {
    this.drag_handlers.push(document.on("mouseup", this.mouseup_event));
    this.drag_handlers.push(document.on("mousemove", this.mousemove_event));
  }

  this.dragging = true;
  this.dragged = false;
  this.dragging_by_touch = touch;
  this.dragging_touch_identifier = touch_identifier;

  this.anchor_x = x;
  this.anchor_y = y;
  this.last_x = this.anchor_x;
  this.last_y = this.anchor_y;

  if(this.options.ondown)
    this.options.ondown({
      dragger: this,
      x: x,
      y: y,
      latest_event: event
    });
}

DragElement.prototype.pagehide_event = function(event)
{
  this.stop_dragging(event, true);
}

DragElement.prototype.touchend_event = function(event)
{
  /* If our touch was released, stop the drag. */
  for(var i = 0; i < event.changedTouches.length; ++i)
  {
    var t = event.changedTouches[i];
    if(t.identifier == this.dragging_touch_identifier)
    {
      this.stop_dragging(event, event.type == "touchcancel");

      /*
       * Work around a bug on iPhone.  The mousedown and mouseup events are sent after
       * the touch is released, instead of when they should be (immediately following
       * touchstart and touchend).  This means we'll process each touch as a touch,
       * then immediately after as a mouse press, and fire ondown/onup events for each.
       *
       * We can't simply ignore mouse presses if touch events are supported; some devices
       * will support both touches and mice and both types of events will always need to
       * be handled.
       *
       * After a touch is released, ignore all mouse presses for a little while.  It's
       * unlikely that the user will touch an element, then immediately click it.
       */
      this.ignore_mouse_events_until = (new Date()).valueOf() + 500;
      return;
    }
  }
}

DragElement.prototype.mouseup_event = function(event)
{
  if(!event.isLeftClick())
    return;

  this.stop_dragging(event, false);
}

/* If cancelling is true, we're stopping for a reason other than an explicit mouse/touch
 * release. */
DragElement.prototype.stop_dragging = function(event, cancelling)
{
  if(this.dragging)
  {
    this.dragging = false;
    $(document.body).removeClassName(this.overriden_drag_class || "dragging");
    $(document.body).addClassName("not-dragging");

    if(this.options.onenddrag)
      this.options.onenddrag(this);
  }

  this.drag_handlers.each(function(h) { h.stop(); });
  this.drag_handlers = [];
  this.dragging_touch_identifier = null;

  if(this.options.onup)
    this.options.onup({
      dragger: this,
      latest_event: event,
      cancelling: cancelling
    });
}

DragElement.prototype.click_event = function(event)
{
  /* If this click was part of a drag, cancel the click. */
  if(this.dragged)
    event.stop();
  this.dragged = false;
}

DragElement.prototype.dragstart_event = function(event)
{
  event.preventDefault();
}

DragElement.prototype.selectstart_event = function(event)
{
  /* We need to stop selectstart to prevent drag selection in Chrome.  However, we need
   * to work around a bug: if we stop the event of an INPUT element, it'll prevent focusing
   * on that element entirely.  We shouldn't prevent selecting the text in the input box,
   * either. */
  if(event.target.tagName != "INPUT")
    event.stop();
}

/* When element is dragged, the document moves around it.  If scroll_element is true, the
 * element should be positioned (eg. position: absolute), and the element itself will be
 * scrolled. */
WindowDragElement = function(element)
{
  this.element = element;
  this.dragger = new DragElement(element, {
    no_touch: true,
    ondrag: this.ondrag.bind(this),
    onstartdrag: this.startdrag.bind(this)
  });
}

WindowDragElement.prototype.startdrag = function()
{
  this.scroll_anchor_x = (window.pageXOffset || document.documentElement.scrollLeft || document.body.scrollLeft);
  this.scroll_anchor_y = (window.pageYOffset || document.documentElement.scrollTop || document.body.scrollTop);
}

WindowDragElement.prototype.ondrag = function(e)
{
  var scrollLeft = this.scroll_anchor_x - e.aX;
  var scrollTop = this.scroll_anchor_y - e.aY;
  scrollTo(scrollLeft, scrollTop);
}

/* element should be positioned (eg. position: absolute).  When the element is dragged,
 * scroll it around. */
WindowDragElementAbsolute = function(element, ondrag_callback)
{
  this.element = element;
  this.ondrag_callback = ondrag_callback;
  this.disabled = false;
  this.dragger = new DragElement(element, {
    ondrag: this.ondrag.bind(this),
    onstartdrag: this.startdrag.bind(this)
  });
}

WindowDragElementAbsolute.prototype.set_disabled = function(b) { this.disabled = b; }

WindowDragElementAbsolute.prototype.startdrag = function()
{
  if(this.disabled)
    return true; /* cancel */

  this.scroll_anchor_x = this.element.offsetLeft;
  this.scroll_anchor_y = this.element.offsetTop;
  return false;
}

WindowDragElementAbsolute.prototype.ondrag = function(e)
{
  var scrollLeft = this.scroll_anchor_x + e.aX;
  var scrollTop = this.scroll_anchor_y + e.aY;

  /* Don't allow dragging the image off the screen; there'll be no way to
   * get it back. */
  var window_size = getWindowSize();
  var min_visible = Math.min(100, this.element.offsetWidth);
  scrollLeft = Math.max(scrollLeft, min_visible - this.element.offsetWidth);
  scrollLeft = Math.min(scrollLeft, window_size.width - min_visible);

  var min_visible = Math.min(100, this.element.offsetHeight);
  scrollTop = Math.max(scrollTop, min_visible - this.element.offsetHeight);
  scrollTop = Math.min(scrollTop, window_size.height - min_visible);
  this.element.setStyle({left: scrollLeft + "px", top: scrollTop + "px"});

  if(this.ondrag_callback)
    this.ondrag_callback();
}

WindowDragElementAbsolute.prototype.destroy = function()
{
  this.dragger.destroy();
}

/* Track the focused element, and store it in document.focusedElement.. */
function TrackFocus()
{
  document.focusedElement = null;
  if(document.addEventListener)
  {
    document.addEventListener("focus", function(e)
    {
      document.focusedElement = e.target;
    }.bindAsEventListener(this), true);
  }
  document.observe("focusin", function(event) {
    document.focusedElement = event.srcElement;
  }.bindAsEventListener(this));
}

function FormatError(message, file, line, exc, info)
{
  var report = "";
  report += "Error: " + message + "\n";

  if(info != null)
    report += info;

  report += "UA: " + window.navigator.userAgent + "\n";
  report += "URL: " + window.location.href + "\n";

  var cookies = document.cookie;
  cookies = cookies.replace(/(pass_hash)=[0-9a-f]{40}/, "$1=(removed)");
  try {
    report += "Cookies: " + decodeURIComponent(cookies) + "\n";
  } catch(e) {
    report += "Cookies (couldn't decode): " + cookies + "\n";
  }

  if("localStorage" in window)
  {
    /* FF's localStorage is broken; we can't iterate over it.  Name the keys we use explicitly. */
    var keys = [];
    try {
      for(key in localStorage)
        keys.push(keys);
    } catch(e) {
      keys = ["sample_urls", "sample_url_fifo", "tag_data", "tag_data_version", "recent_tags", "tag_data_format"];
    }

    for(var i = 0; i < keys.length; ++i)
    {
      var key = keys[i];
      try {
        if(!(key in localStorage))
          continue;

        var data = localStorage[key];
        var length = data.length;
        if(data.length > 512)
          data = data.slice(0, 512);

        report += "localStorage." + key + " (size: " + length + "): " + data + "\n";
      } catch(e) {
        report += "(ignored errors retrieving localStorage for " + key + ": " + e + ")\n";
      }
    }
  }

  if(exc && exc.stack)
    report += "\n" + exc.stack + "\n";

  if(file)
  {
    report += "File: " + file;
    if(line != null)
      report += " line " + line + "\n";
  }

  return report;
}

var reported_error = false;
function ReportError(message, file, line, exc, info)
{
  if(navigator.userAgent.match(/.*MSIE [67]/))
    return;

  /* Only attempt to report an error once per page load. */
  if(reported_error)
    return;
  reported_error = true;

  /* Only report an error at most once per hour. */
  if(document.cookie.indexOf("reported_error=1") != -1)
    return;

  var expiration = new Date();
  expiration.setTime(expiration.getTime() + (60 * 60 * 1000));
  document.cookie = "reported_error=1; path=/; expires=" + expiration.toGMTString();

  var report = FormatError(exc? exc.message:message, file, line, exc, info);

  try {
    new Ajax.Request("/user/error.json", {
      parameters: { report: report }
    });
  } catch(e) {
    alert("Error: " + e);
  }
}

function LocalStorageDisabled()
{
  if(!("localStorage" in window))
    return "unsupported";

  var cleared_storage = false;
  while(1)
  {
    try {
      /* We can't just access a property to test it; that detects it being disabled in FF, but
       * not in Chrome. */
      localStorage.x = 1;
      if(localStorage.x != 1)
        throw "disabled";
      delete localStorage.x;
      return null;
    } catch(e) {
      /* If local storage is full, we may not be able to even run this test.  If that ever happens
       * something is wrong, so after a failure clear localStorage once and try again.  This call
       * may fail, too; ignore that and we'll catch the problem on the next try. */
      if(!cleared_storage)
      {
        cleared_storage = true;
        try {
          localStorage.clear();
        } catch(e) { }
        continue;
      }
      if(navigator.userAgent.indexOf("Gecko/") != -1)
      {
        // If the user or an extension toggles about:config dom.storage.enabled, this happens:
        if(e.message.indexOf("Security error") != -1)
          return "ff-disabled";
      }

      /* Chrome unhelpfully reports QUOTA_EXCEEDED_ERR if local storage is disabled, which
       * means we can't easily detect it being disabled and show a tip to the user. */
      return "error";
    }
  }
}

/* Chrome 10/WebKit braindamage; stop breaking things intentionally just to create
 * busywork for everyone else: */
if(!("URL" in window) && "webkitURL" in window)
  window.URL = window.webkitURL;

/* For Chrome 9: */
if("createObjectURL" in window && !("URL" in window))
{
  window.URL = {
    createObjectURL: function(blob) { return window.createObjectURL(blob); },
    revokeObjectURL: function(url) { window.revokeObjectURL(url); }
  }
}

/* Allow CSS styles for WebKit. */
if(navigator.userAgent.indexOf("AppleWebKit/") != -1)
  document.documentElement.className += " webkit";



Cookie = {
  put: function(name, value, days) {
    if (days == null) {
      days = 365
    }

    var date = new Date()
    date.setTime(date.getTime() + (days * 24 * 60 * 60 * 1000))
    var expires = "; expires=" + date.toGMTString()
    document.cookie = name + "=" + window.encodeURIComponent(value) + expires + "; path=/"
  },

  raw_get: function(name) {
    var nameEq = name + "="
    var ca = document.cookie.split(";")

    for (var i = 0; i < ca.length; ++i) {
      var c = ca[i]

      while (c.charAt(0) == " ") {
        c = c.substring(1, c.length)
      }

      if (c.indexOf(nameEq) == 0) {
        return c.substring(nameEq.length, c.length)
      }
    }

    return ""
  },
  
  get: function(name) {
    return this.unescape(this.raw_get(name))
  },

  get_int: function(name) {
    var value = Cookie.get(name);
    value = parseInt(value);
    if(value)
      return value;
    else
      return 0;
  },
  
  remove: function(name) {
    Cookie.put(name, "", -1)
  },

  unescape: function(val) {
    return window.decodeURIComponent(val.replace(/\+/g, " "))
  },

  setup: function() {
    if (location.href.match(/^\/(comment|pool|note|post)/) && this.get("tos") != "1") {
      // Setting location.pathname in Safari doesn't work, so manually extract the domain.
      var domain = location.href.match(/^(http:\/\/[^\/]+)/)[0]
      location.href = domain + "/static/terms_of_service?url=" + location.href
      return
    }
    
    if (this.get("has_mail") == "1") {
      $("has-mail-notice").show()
    }
  
    var mod_pending = this.get("mod_pending");
    if (mod_pending && parseInt(mod_pending) > "0") {
      if($("moderate"))
        $("moderate").addClassName("mod-pending")
    }
  
    if (this.get("forum_updated") == "1") {
      $("forum-link").addClassName("forum-update")
    }
  
    if (this.get("comments_updated") == "1") {
      $("comments-link").addClassName("comments-update")
    }
  
    if (this.get("block_reason") != "") {
      $("block-reason").update(this.get("block_reason")).show()
    }

		if (this.get("hide-upgrade-account") == "1") {
      if ($("upgrade-account")) {
   	    $("upgrade-account").hide()
      }
		}

    if ($("my-favorites")) {
      if (this.get("login") != "") {
        $("my-favorites").href = "/post/index?tags=vote%3A3%3A" + Cookie.get("login") + "%20order%3Avote"
      } else {
        $("my-favorites-container").hide()
      }
    }
  }
}


/**
 * Image Cropper (v. 1.2.0 - 2006-10-30 )
 * Copyright (c) 2006 David Spurr (http://www.defusion.org.uk/)
 * 
 * The image cropper provides a way to draw a crop area on an image and capture
 * the coordinates of the drawn crop area.
 * 
 * Features include:
 * 		- Based on Prototype and Scriptaculous
 * 		- Image editing package styling, the crop area functions and looks 
 * 		  like those found in popular image editing software
 * 		- Dynamic inclusion of required styles
 * 		- Drag to draw areas
 * 		- Shift drag to draw/resize areas as squares
 * 		- Selection area can be moved 
 * 		- Seleciton area can be resized using resize handles
 * 		- Allows dimension ratio limited crop areas
 * 		- Allows minimum dimension crop areas
 * 		- Allows maximum dimesion crop areas
 * 		- If both min & max dimension options set to the same value for a single axis,then the cropper will not 
 * 		  display the resize handles as appropriate (when min & max dimensions are passed for both axes this
 * 		  results in a 'fixed size' crop area)
 * 		- Allows dynamic preview of resultant crop ( if minimum width & height are provided ), this is
 * 		  implemented as a subclass so can be excluded when not required
 * 		- Movement of selection area by arrow keys ( shift + arrow key will move selection area by
 * 		  10 pixels )
 *		- All operations stay within bounds of image
 * 		- All functionality & display compatible with most popular browsers supported by Prototype:
 * 			PC:	IE 7, 6 & 5.5, Firefox 1.5, Opera 8.5 (see known issues) & 9.0b
 * 			MAC: Camino 1.0, Firefox 1.5, Safari 2.0
 * 
 * Requires:
 * 		- Prototype v. 1.5.0_rc0 > (as packaged with Scriptaculous 1.6.1)
 * 		- Scriptaculous v. 1.6.1 > modules: builder, dragdrop 
 * 		
 * Known issues:
 * 		- Safari animated gifs, only one of each will animate, this seems to be a known Safari issue
 * 
 * 		- After drawing an area and then clicking to start a new drag in IE 5.5 the rendered height 
 *        appears as the last height until the user drags, this appears to be the related to the error 
 *        that the forceReRender() method fixes for IE 6, i.e. IE 5.5 is not redrawing the box properly.
 * 
 * 		- Lack of CSS opacity support in Opera before version 9 mean we disable those style rules, these 
 * 		  could be fixed by using PNGs with transparency if Opera 8.5 support is high priority for you
 * 
 * 		- Marching ants keep reloading in IE <6 (not tested in IE7), it is a known issue in IE and I have 
 *        found no viable workarounds that can be included in the release. If this really is an issue for you
 *        either try this post: http://mir.aculo.us/articles/2005/08/28/internet-explorer-and-ajax-image-caching-woes
 *        or uncomment the 'FIX MARCHING ANTS IN IE' rules in the CSS file
 *		
 *		- Styling & borders on image, any CSS styling applied directly to the image itself (floats, borders, padding, margin, etc.) will 
 *		  cause problems with the cropper. The use of a wrapper element to apply these styles to is recommended.
 * 
 * 		- overflow: auto or overflow: scroll on parent will cause cropper to burst out of parent in IE and Opera (maybe Mac browsers too)
 *		  I'm not sure why yet.
 * 
 * Usage:
 * 		See Cropper.Img & Cropper.ImgWithPreview for usage details
 * 
 * Changelog:
 * v1.2.0 - 2006-10-30
 * 		+ Added id to the preview image element using 'imgCrop_[originalImageID]'
 *      * #00001 - Fixed bug: Doesn't account for scroll offsets
 *      * #00009 - Fixed bug: Placing the cropper inside differently positioned elements causes incorrect co-ordinates and display
 *      * #00013 - Fixed bug: I-bar cursor appears on drag plane
 *      * #00014 - Fixed bug: If ID for image tag is not found in document script throws error
 *      * Fixed bug with drag start co-ordinates if wrapper element has moved in browser (e.g. dragged to a new position)
 *      * Fixed bug with drag start co-ordinates if image contained in a wrapper with scrolling - this may be buggy if image 
 * 		  has other ancestors with scrolling applied (except the body)
 *      * #00015 - Fixed bug: When cropper removed and then reapplied onEndCrop callback gets called multiple times, solution suggestion from Bill Smith
 *      * Various speed increases & code cleanup which meant improved performance in Mac - which allowed removal of different overlay methods for
 *        IE and all other browsers, which led to a fix for:
 * 		* #00010 - Fixed bug: Select area doesn't adhere to image size when image resized using img attributes
 *      - #00006 - Removed default behaviour of automatically setting a ratio when both min width & height passed, the ratioDimensions must be passed in
 * 		+ #00005 - Added ability to set maximum crop dimensions, if both min & max set as the same value then we'll get a fixed cropper size on the axes as appropriate
 *        and the resize handles will not be displayed as appropriate
 * 		* Switched keydown for keypress for moving select area with cursor keys (makes for nicer action) - doesn't appear to work in Safari
 * 
 * v1.1.3 - 2006-08-21
 * 		* Fixed wrong cursor on western handle in CSS
 * 		+ #00008 & #00003 - Added feature: Allow to set dimensions & position for cropper on load
 *      * #00002 - Fixed bug: Pressing 'remove cropper' twice removes image in IE
 * 
 * v1.1.2 - 2006-06-09
 * 		* Fixed bugs with ratios when GCD is low (patch submitted by Andy Skelton)
 * 
 * v1.1.1 - 2006-06-03
 * 		* Fixed bug with rendering issues fix in IE 5.5
 * 		* Fixed bug with endCrop callback issues once cropper had been removed & reset in IE
 * 
 * v1.1.0 - 2006-06-02
 * 		* Fixed bug with IE constantly trying to reload select area background image
 * 		* Applied more robust fix to Safari & IE rendering issues
 * 		+ Added method to reset parameters - useful for when dynamically changing img cropper attached to
 * 		+ Added method to remove cropper from image
 * 
 * v1.0.0 - 2006-05-18 
 * 		+ Initial verison
 * 
 * 
 * Copyright (c) 2006, David Spurr (http://www.defusion.org.uk/)
 * All rights reserved.
 * 
 * 
 * Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 * 
 *     * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 *     * Neither the name of the David Spurr nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 * 
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 * 
 * http://www.opensource.org/licenses/bsd-license.php
 * 
 * See scriptaculous.js for full scriptaculous licence
 */
 
/**
 * Extend the Draggable class to allow us to pass the rendering
 * down to the Cropper object.
 */
var CropDraggable = Class.create();

Object.extend( Object.extend( CropDraggable.prototype, Draggable.prototype), {
	
	initialize: function(element) {
		this.options = Object.extend(
			{
				/**
				 * The draw method to defer drawing to
				 */
				drawMethod: function() {}
			}, 
			arguments[1] || {}
		);

		this.element = $(element);

		this.handle = this.element;

		this.delta    = this.currentDelta();
		this.dragging = false;   

		this.eventMouseDown = this.initDrag.bindAsEventListener(this);
		Event.observe(this.handle, "mousedown", this.eventMouseDown);

		Draggables.register(this);
	},
	
	/**
	 * Defers the drawing of the draggable to the supplied method
	 */
	draw: function(point) {
		var pos = Position.cumulativeOffset(this.element);
		var d = this.currentDelta();
		pos[0] -= d[0]; 
		pos[1] -= d[1];
				
		var p = [0,1].map(function(i) { 
			return (point[i]-pos[i]-this.offset[i]) 
		}.bind(this));
				
		this.options.drawMethod( p );
	}
	
});


/**
 * The Cropper object, this will attach itself to the provided image by wrapping it with 
 * the generated xHTML structure required by the cropper.
 * 
 * Usage:
 * 	@param obj Image element to attach to
 * 	@param obj Optional options:
 * 		- ratioDim obj 
 * 			The pixel dimensions to apply as a restrictive ratio, with properties x & y
 * 
 * 		- minWidth int 
 * 			The minimum width for the select area in pixels
 * 
 * 		- minHeight	int 
 * 			The mimimum height for the select area in pixels
 * 
 * 		- maxWidth int
 * 			The maximum width for the select areas in pixels (if both minWidth & maxWidth set to same the width of the cropper will be fixed)
 * 
 * 		- maxHeight int
 *			The maximum height for the select areas in pixels (if both minHeight & maxHeight set to same the height of the cropper will be fixed)
 * 
 * 		- displayOnInit int 
 * 			Whether to display the select area on initialisation, only used when providing minimum width & height or ratio
 * 
 * 		- onEndCrop func
 * 			The callback function to provide the crop details to on end of a crop (see below)
 * 
 * 		- captureKeys boolean
 * 			Whether to capture the keys for moving the select area, as these can cause some problems at the moment
 * 
 * 		- onloadCoords obj
 * 			A coordinates object with properties x1, y1, x2 & y2; for the coordinates of the select area to display onload
 * 	
 *----------------------------------------------
 * 
 * The callback function provided via the onEndCrop option should accept the following parameters:
 * 		- coords obj
 * 			The coordinates object with properties x1, y1, x2 & y2; for the coordinates of the select area
 * 
 * 		- dimensions obj
 * 			The dimensions object with properites width & height; for the dimensions of the select area
 * 		
 *
 * 		Example:
 * 			function onEndCrop( coords, dimensions ) {
 *				$( 'x1' ).value 	= coords.x1;
 *				$( 'y1' ).value 	= coords.y1;
 *				$( 'x2' ).value 	= coords.x2;
 *				$( 'y2' ).value 	= coords.y2;
 *				$( 'width' ).value 	= dimensions.width;
 *				$( 'height' ).value	= dimensions.height;
 *			}
 * 
 */
var Cropper = {};
Cropper.Img = Class.create();
Cropper.Img.prototype = {
	
	/**
	 * Initialises the class
	 * 
	 * @access public
	 * @param obj Image element to attach to
	 * @param obj Options
	 * @return void
	 */
	initialize: function(element, options) {
		this.options = Object.extend(
			{
				/**
				 * @var obj
				 * The pixel dimensions to apply as a restrictive ratio
				 */
				ratioDim: { x: 0, y: 0 },
				/**
				 * @var int
				 * The minimum pixel width, also used as restrictive ratio if min height passed too
				 */
				minWidth:		0,
				/**
				 * @var int
				 * The minimum pixel height, also used as restrictive ratio if min width passed too
				 */
				minHeight:		0,
				/**
				 * @var boolean
				 * Whether to display the select area on initialisation, only used when providing minimum width & height or ratio
				 */
				displayOnInit:	false,
				/**
				 * @var function
				 * The call back function to pass the final values to
				 */
				onEndCrop: Prototype.emptyFunction,
				/**
				 * @var boolean
				 * Whether to capture key presses or not
				 */
				captureKeys: true,
				/**
				 * @var obj Coordinate object x1, y1, x2, y2
				 * The coordinates to optionally display the select area at onload
				 */
				onloadCoords: null,
				/**
				 * @var int
				 * The maximum width for the select areas in pixels (if both minWidth & maxWidth set to same the width of the cropper will be fixed)
				 */
				maxWidth: 0,
				/**
				 * @var int
				 * The maximum height for the select areas in pixels (if both minHeight & maxHeight set to same the height of the cropper will be fixed)
				 */
				maxHeight: 0
			}, 
			options || {}
		);				
		/**
		 * @var obj
		 * The img node to attach to
		 */
		this.img			= $( element );
		/**
		 * @var obj
		 * The x & y coordinates of the click point
		 */
		this.clickCoords	= { x: 0, y: 0 };
		/**
		 * @var boolean
		 * Whether the user is dragging
		 */
		this.dragging		= false;
		/**
		 * @var boolean
		 * Whether the user is resizing
		 */
		this.resizing		= false;
		/**
		 * @var boolean
		 * Whether the user is on a webKit browser
		 */
		this.isWebKit 		= /Konqueror|Safari|KHTML/.test( navigator.userAgent );
		/**
		 * @var boolean
		 * Whether the user is on IE
		 */
		this.isIE 			= /MSIE/.test( navigator.userAgent );
		/**
		 * @var boolean
		 * Whether the user is on Opera below version 9
		 */
		this.isOpera8		= /Opera\s[1-8]/.test( navigator.userAgent );
		/**
		 * @var int
		 * The x ratio 
		 */
		this.ratioX			= 0;
		/**
		 * @var int
		 * The y ratio
		 */
		this.ratioY			= 0;
		/**
		 * @var boolean
		 * Whether we've attached sucessfully
		 */
		this.attached		= false;
		/**
		 * @var boolean
		 * Whether we've got a fixed width (if minWidth EQ or GT maxWidth then we have a fixed width
		 * in the case of minWidth > maxWidth maxWidth wins as the fixed width)
		 */
		this.fixedWidth		= ( this.options.maxWidth > 0 && ( this.options.minWidth >= this.options.maxWidth ) );
		/**
		 * @var boolean
		 * Whether we've got a fixed height (if minHeight EQ or GT maxHeight then we have a fixed height
		 * in the case of minHeight > maxHeight maxHeight wins as the fixed height)
		 */
		this.fixedHeight	= ( this.options.maxHeight > 0 && ( this.options.minHeight >= this.options.maxHeight ) );
		
		// quit if the image element doesn't exist
		if( typeof this.img == 'undefined' ) return;
				
		// calculate the ratio when neccessary
		if( this.options.ratioDim.x > 0 && this.options.ratioDim.y > 0 ) {
			var gcd = this.getGCD( this.options.ratioDim.x, this.options.ratioDim.y );
			this.ratioX = this.options.ratioDim.x / gcd;
			this.ratioY = this.options.ratioDim.y / gcd;
			// dump( 'RATIO : ' + this.ratioX + ':' + this.ratioY + '\n' );
		}
							
		// initialise sub classes
		this.subInitialize();

		// only load the event observers etc. once the image is loaded
		// this is done after the subInitialize() call just in case the sub class does anything
		// that will affect the result of the call to onLoad()
		if( this.img.complete || this.isWebKit ) this.onLoad(); // for some reason Safari seems to support img.complete but returns 'undefined' on the this.img object
		else Event.observe( this.img, 'load', this.onLoad.bindAsEventListener( this) );		
	},
	
	/**
	 * The Euclidean algorithm used to find the greatest common divisor
	 * 
	 * @acces private
	 * @param int Value 1
	 * @param int Value 2
	 * @return int
	 */
	getGCD : function( a , b ) {
		if( b == 0 ) return a;
		return this.getGCD(b, a % b );
	},
	
	/**
	 * Attaches the cropper to the image once it has loaded
	 * 
	 * @access private
	 * @return void
	 */
	onLoad: function( ) {
		/*
		 * Build the container and all related elements, will result in the following
		 *
		 * <div class="imgCrop_wrap">
		 * 		<img ... this.img ... />
		 * 		<div class="imgCrop_dragArea">
		 * 			<!-- the inner spans are only required for IE to stop it making the divs 1px high/wide -->
		 * 			<div class="imgCrop_overlay imageCrop_north"><span></span></div>
		 * 			<div class="imgCrop_overlay imageCrop_east"><span></span></div>
		 * 			<div class="imgCrop_overlay imageCrop_south"><span></span></div>
		 * 			<div class="imgCrop_overlay imageCrop_west"><span></span></div>
		 * 			<div class="imgCrop_selArea">
		 * 				<!-- marquees -->
		 * 				<!-- the inner spans are only required for IE to stop it making the divs 1px high/wide -->
		 * 				<div class="imgCrop_marqueeHoriz imgCrop_marqueeNorth"><span></span></div>
		 * 				<div class="imgCrop_marqueeVert imgCrop_marqueeEast"><span></span></div>
		 * 				<div class="imgCrop_marqueeHoriz imgCrop_marqueeSouth"><span></span></div>
		 * 				<div class="imgCrop_marqueeVert imgCrop_marqueeWest"><span></span></div>			
		 * 				<!-- handles -->
		 * 				<div class="imgCrop_handle imgCrop_handleN"></div>
		 * 				<div class="imgCrop_handle imgCrop_handleNE"></div>
		 * 				<div class="imgCrop_handle imgCrop_handleE"></div>
		 * 				<div class="imgCrop_handle imgCrop_handleSE"></div>
		 * 				<div class="imgCrop_handle imgCrop_handleS"></div>
		 * 				<div class="imgCrop_handle imgCrop_handleSW"></div>
		 * 				<div class="imgCrop_handle imgCrop_handleW"></div>
		 * 				<div class="imgCrop_handle imgCrop_handleNW"></div>
		 * 				<div class="imgCrop_clickArea"></div>
		 * 			</div>	
		 * 			<div class="imgCrop_clickArea"></div>
		 * 		</div>	
		 * </div>
		 */
		var cNamePrefix = 'imgCrop_';
		
		// get the point to insert the container
		var insertPoint = this.img.parentNode;
		
		// apply an extra class to the wrapper to fix Opera below version 9
		var fixOperaClass = '';
		if( this.isOpera8 ) fixOperaClass = ' opera8';
		this.imgWrap = Builder.node( 'div', { 'class': cNamePrefix + 'wrap' + fixOperaClass } );
		
		this.north		= Builder.node( 'div', { 'class': cNamePrefix + 'overlay ' + cNamePrefix + 'north' }, [Builder.node( 'span' )] );
		this.east		= Builder.node( 'div', { 'class': cNamePrefix + 'overlay ' + cNamePrefix + 'east' } , [Builder.node( 'span' )] );
		this.south		= Builder.node( 'div', { 'class': cNamePrefix + 'overlay ' + cNamePrefix + 'south' }, [Builder.node( 'span' )] );
		this.west		= Builder.node( 'div', { 'class': cNamePrefix + 'overlay ' + cNamePrefix + 'west' } , [Builder.node( 'span' )] );
		
		var overlays	= [ this.north, this.east, this.south, this.west ];

		this.dragArea	= Builder.node( 'div', { 'class': cNamePrefix + 'dragArea' }, overlays );
						
		this.handleN	= Builder.node( 'div', { 'class': cNamePrefix + 'handle ' + cNamePrefix + 'handleN' } );
		this.handleNE	= Builder.node( 'div', { 'class': cNamePrefix + 'handle ' + cNamePrefix + 'handleNE' } );
		this.handleE	= Builder.node( 'div', { 'class': cNamePrefix + 'handle ' + cNamePrefix + 'handleE' } );
		this.handleSE	= Builder.node( 'div', { 'class': cNamePrefix + 'handle ' + cNamePrefix + 'handleSE' } );
		this.handleS	= Builder.node( 'div', { 'class': cNamePrefix + 'handle ' + cNamePrefix + 'handleS' } );
		this.handleSW	= Builder.node( 'div', { 'class': cNamePrefix + 'handle ' + cNamePrefix + 'handleSW' } );
		this.handleW	= Builder.node( 'div', { 'class': cNamePrefix + 'handle ' + cNamePrefix + 'handleW' } );
		this.handleNW	= Builder.node( 'div', { 'class': cNamePrefix + 'handle ' + cNamePrefix + 'handleNW' } );
				
		this.selArea	= Builder.node( 'div', { 'class': cNamePrefix + 'selArea' },
			[
				Builder.node( 'div', { 'class': cNamePrefix + 'marqueeHoriz ' + cNamePrefix + 'marqueeNorth' }, [Builder.node( 'span' )] ),
				Builder.node( 'div', { 'class': cNamePrefix + 'marqueeVert ' + cNamePrefix + 'marqueeEast' }  , [Builder.node( 'span' )] ),
				Builder.node( 'div', { 'class': cNamePrefix + 'marqueeHoriz ' + cNamePrefix + 'marqueeSouth' }, [Builder.node( 'span' )] ),
				Builder.node( 'div', { 'class': cNamePrefix + 'marqueeVert ' + cNamePrefix + 'marqueeWest' }  , [Builder.node( 'span' )] ),
				this.handleN,
				this.handleNE,
				this.handleE,
				this.handleSE,
				this.handleS,
				this.handleSW,
				this.handleW,
				this.handleNW,
				Builder.node( 'div', { 'class': cNamePrefix + 'clickArea' } )
			]
		);
				
		this.imgWrap.appendChild( this.img );
		this.imgWrap.appendChild( this.dragArea );
		this.dragArea.appendChild( this.selArea );
		this.dragArea.appendChild( Builder.node( 'div', { 'class': cNamePrefix + 'clickArea' } ) );

		insertPoint.appendChild( this.imgWrap );

		// add event observers
		this.startDragBind 	= this.startDrag.bindAsEventListener( this );
		Event.observe( this.dragArea, 'mousedown', this.startDragBind );
		
		this.onDragBind 	= this.onDrag.bindAsEventListener( this );
		Event.observe( document, 'mousemove', this.onDragBind );
		
		this.endCropBind 	= this.endCrop.bindAsEventListener( this );
		Event.observe( document, 'mouseup', this.endCropBind );
		
		this.resizeBind		= this.startResize.bindAsEventListener( this );
		this.handles = [ this.handleN, this.handleNE, this.handleE, this.handleSE, this.handleS, this.handleSW, this.handleW, this.handleNW ];
		this.registerHandles( true );
		
		if( this.options.captureKeys ) {
			this.keysBind = this.handleKeys.bindAsEventListener( this );
			Event.observe( document, 'keypress', this.keysBind );
		}

		// attach the dragable to the select area
		new CropDraggable( this.selArea, { drawMethod: this.moveArea.bindAsEventListener( this ) } );
		
		this.setParams();
	},
	
	/**
	 * Manages adding or removing the handle event handler and hiding or displaying them as appropriate
	 * 
	 * @access private
	 * @param boolean registration true = add, false = remove
	 * @return void
	 */
	registerHandles: function( registration ) {	
		for( var i = 0; i < this.handles.length; i++ ) {
			var handle = $( this.handles[i] );
			
			if( registration ) {
				var hideHandle	= false;	// whether to hide the handle
				
				// disable handles asappropriate if we've got fixed dimensions
				// if both dimensions are fixed we don't need to do much
				if( this.fixedWidth && this.fixedHeight ) hideHandle = true;
				else if( this.fixedWidth || this.fixedHeight ) {
					// if one of the dimensions is fixed then just hide those handles
					var isCornerHandle	= handle.className.match( /([S|N][E|W])$/ )
					var isWidthHandle 	= handle.className.match( /(E|W)$/ );
					var isHeightHandle 	= handle.className.match( /(N|S)$/ );
					if( isCornerHandle ) hideHandle = true;
					else if( this.fixedWidth && isWidthHandle ) hideHandle = true;
					else if( this.fixedHeight && isHeightHandle ) hideHandle = true;
				}
				if( hideHandle ) handle.hide();
				else Event.observe( handle, 'mousedown', this.resizeBind );
			} else {
				handle.show();
				Event.stopObserving( handle, 'mousedown', this.resizeBind );
			}
		}
	},
		
	/**
	 * Sets up all the cropper parameters, this can be used to reset the cropper when dynamically
	 * changing the images
	 * 
	 * @access private
	 * @return void
	 */
	setParams: function() {
		/**
		 * @var int
		 * The image width
		 */
		this.imgW = this.img.width;
		/**
		 * @var int
		 * The image height
		 */
		this.imgH = this.img.height;			

		$( this.north ).setStyle( { height: 0 } );
		$( this.east ).setStyle( { width: 0, height: 0 } );
		$( this.south ).setStyle( { height: 0 } );
		$( this.west ).setStyle( { width: 0, height: 0 } );
		
		// resize the container to fit the image
		$( this.imgWrap ).setStyle( { 'width': this.imgW + 'px', 'height': this.imgH + 'px' } );
		
		// hide the select area
		$( this.selArea ).hide();
						
		// setup the starting position of the select area
		var startCoords = { x1: 0, y1: 0, x2: 0, y2: 0 };
		var validCoordsSet = false;
		
		// display the select area 
		if( this.options.onloadCoords != null ) {
			// if we've being given some coordinates to 
			startCoords = this.cloneCoords( this.options.onloadCoords );
			validCoordsSet = true;
		} else if( this.options.ratioDim.x > 0 && this.options.ratioDim.y > 0 ) {
			// if there is a ratio limit applied and the then set it to initial ratio
			startCoords.x1 = Math.ceil( ( this.imgW - this.options.ratioDim.x ) / 2 );
			startCoords.y1 = Math.ceil( ( this.imgH - this.options.ratioDim.y ) / 2 );
			startCoords.x2 = startCoords.x1 + this.options.ratioDim.x;
			startCoords.y2 = startCoords.y1 + this.options.ratioDim.y;
			validCoordsSet = true;
		}
		
		this.setAreaCoords( startCoords, false, false, 1 );
		
		if( this.options.displayOnInit && validCoordsSet ) {
			this.selArea.show();
			this.drawArea();
			this.endCrop();
		}
		
		this.attached = true;
	},
	
	/**
	 * Removes the cropper
	 * 
	 * @access public
	 * @return void
	 */
	remove: function() {
		if( this.attached ) {
			this.attached = false;
			
			// remove the elements we inserted
			this.imgWrap.parentNode.insertBefore( this.img, this.imgWrap );
			this.imgWrap.parentNode.removeChild( this.imgWrap );
			
			// remove the event observers
			Event.stopObserving( this.dragArea, 'mousedown', this.startDragBind );
			Event.stopObserving( document, 'mousemove', this.onDragBind );		
			Event.stopObserving( document, 'mouseup', this.endCropBind );
			this.registerHandles( false );
			if( this.options.captureKeys ) Event.stopObserving( document, 'keypress', this.keysBind );
		}
	},
	
	/**
	 * Resets the cropper, can be used either after being removed or any time you wish
	 * 
	 * @access public
	 * @return void
	 */
	reset: function() {
		if( !this.attached ) this.onLoad();
		else this.setParams();
		this.endCrop();
	},
	
	/**
	 * Handles the key functionality, currently just using arrow keys to move, if the user
	 * presses shift then the area will move by 10 pixels
	 */
	handleKeys: function( e ) {
		var dir = { x: 0, y: 0 }; // direction to move it in & the amount in pixels
		if( !this.dragging && !e.altKey ) {
			// catch the arrow keys
			switch( e.keyCode ) {
				case( 37 ) : // left
					dir.x = -1;
					break;
				case( 38 ) : // up
					dir.y = -1;
					break;
				case( 39 ) : // right
					dir.x = 1;
					break
				case( 40 ) : // down
					dir.y = 1;
					break;
			}
			
			if( dir.x != 0 || dir.y != 0 ) {
				// if shift is pressed then move by 10 pixels
				if( e.shiftKey ) {
					dir.x *= 10;
					dir.y *= 10;
				}
				
				this.moveArea( [ this.areaCoords.x1 + dir.x, this.areaCoords.y1 + dir.y ] );
				Event.stop( e ); 
			}
		}
	},
	
	/**
	 * Calculates the width from the areaCoords
	 * 
	 * @access private
	 * @return int
	 */
	calcW: function() {
		return (this.areaCoords.x2 - this.areaCoords.x1)
	},
	
	/**
	 * Calculates the height from the areaCoords
	 * 
	 * @access private
	 * @return int
	 */
	calcH: function() {
		return (this.areaCoords.y2 - this.areaCoords.y1)
	},
	
	/**
	 * Moves the select area to the supplied point (assumes the point is x1 & y1 of the select area)
	 * 
	 * @access public
	 * @param array Point for x1 & y1 to move select area to
	 * @return void
	 */
	moveArea: function( point ) {
		// dump( 'moveArea        : ' + point[0] + ',' + point[1] + ',' + ( point[0] + ( this.areaCoords.x2 - this.areaCoords.x1 ) ) + ',' + ( point[1] + ( this.areaCoords.y2 - this.areaCoords.y1 ) ) + '\n' );
		this.setAreaCoords( 
			{
				x1: point[0], 
				y1: point[1],
				x2: point[0] + this.calcW(),
				y2: point[1] + this.calcH()
			},
			true,
			false
		);
		this.drawArea();
	},

	/**
	 * Clones a co-ordinates object, stops problems with handling them by reference
	 * 
	 * @access private
	 * @param obj Coordinate object x1, y1, x2, y2
	 * @return obj Coordinate object x1, y1, x2, y2
	 */
	cloneCoords: function( coords ) {
		return { x1: coords.x1, y1: coords.y1, x2: coords.x2, y2: coords.y2 };
	},

	/**
	 * Sets the select coords to those provided but ensures they don't go
	 * outside the bounding box
	 * 
	 * @access private
	 * @param obj Coordinates x1, y1, x2, y2
	 * @param boolean Whether this is a move
	 * @param boolean Whether to apply squaring
	 * @param obj Direction of mouse along both axis x, y ( -1 = negative, 1 = positive ) only required when moving etc.
	 * @param string The current resize handle || null
	 * @return void
	 */
	setAreaCoords: function( coords, moving, square, direction, resizeHandle ) {
		// dump( 'setAreaCoords (in) : ' + coords.x1 + ',' + coords.y1 + ',' + coords.x2 + ',' + coords.y2 );
		if( moving ) {
			// if moving
			var targW = coords.x2 - coords.x1;
			var targH = coords.y2 - coords.y1;
			
			// ensure we're within the bounds
			if( coords.x1 < 0 ) {
				coords.x1 = 0;
				coords.x2 = targW;
			}
			if( coords.y1 < 0 ) {
				coords.y1 = 0;
				coords.y2 = targH;
			}
			if( coords.x2 > this.imgW ) {
				coords.x2 = this.imgW;
				coords.x1 = this.imgW - targW;
			}
			if( coords.y2 > this.imgH ) {
				coords.y2 = this.imgH;
				coords.y1 = this.imgH - targH;
			}			
		} else {
			// ensure we're within the bounds
			if( coords.x1 < 0 ) coords.x1 = 0;
			if( coords.y1 < 0 ) coords.y1 = 0;
			if( coords.x2 > this.imgW ) coords.x2 = this.imgW;
			if( coords.y2 > this.imgH ) coords.y2 = this.imgH;
			
			// This is passed as null in onload
			if( direction != null ) {
								
				// apply the ratio or squaring where appropriate
				if( this.ratioX > 0 ) this.applyRatio( coords, { x: this.ratioX, y: this.ratioY }, direction, resizeHandle );
				else if( square ) this.applyRatio( coords, { x: 1, y: 1 }, direction, resizeHandle );
										
				var mins = [ this.options.minWidth, this.options.minHeight ]; // minimum dimensions [x,y]			
				var maxs = [ this.options.maxWidth, this.options.maxHeight ]; // maximum dimensions [x,y]
		
				// apply dimensions where appropriate
				if( mins[0] > 0 || mins[1] > 0 || maxs[0] > 0 || maxs[1] > 0) {
				
					var coordsTransX 	= { a1: coords.x1, a2: coords.x2 };
					var coordsTransY 	= { a1: coords.y1, a2: coords.y2 };
					var boundsX			= { min: 0, max: this.imgW };
					var boundsY			= { min: 0, max: this.imgH };
					
					// handle squaring properly on single axis minimum dimensions
					if( (mins[0] != 0 || mins[1] != 0) && square ) {
						if( mins[0] > 0 ) mins[1] = mins[0];
						else if( mins[1] > 0 ) mins[0] = mins[1];
					}
					
					if( (maxs[0] != 0 || maxs[0] != 0) && square ) {
						// if we have a max x value & it is less than the max y value then we set the y max to the max x (so we don't go over the minimum maximum of one of the axes - if that makes sense)
						if( maxs[0] > 0 && maxs[0] <= maxs[1] ) maxs[1] = maxs[0];
						else if( maxs[1] > 0 && maxs[1] <= maxs[0] ) maxs[0] = maxs[1];
					}
					
					if( mins[0] > 0 ) this.applyDimRestriction( coordsTransX, mins[0], direction.x, boundsX, 'min' );
					if( mins[1] > 1 ) this.applyDimRestriction( coordsTransY, mins[1], direction.y, boundsY, 'min' );
					
					if( maxs[0] > 0 ) this.applyDimRestriction( coordsTransX, maxs[0], direction.x, boundsX, 'max' );
					if( maxs[1] > 1 ) this.applyDimRestriction( coordsTransY, maxs[1], direction.y, boundsY, 'max' );
					
					coords = { x1: coordsTransX.a1, y1: coordsTransY.a1, x2: coordsTransX.a2, y2: coordsTransY.a2 };
				}
				
			}
		}
		
		// dump( 'setAreaCoords (out) : ' + coords.x1 + ',' + coords.y1 + ',' + coords.x2 + ',' + coords.y2 + '\n' );
		this.areaCoords = coords;
	},
	
	/**
	 * Applies the supplied dimension restriction to the supplied coordinates along a single axis
	 * 
	 * @access private
	 * @param obj Single axis coordinates, a1, a2 (e.g. for the x axis a1 = x1 & a2 = x2)
	 * @param int The restriction value
	 * @param int The direction ( -1 = negative, 1 = positive )
	 * @param obj The bounds of the image ( for this axis )
	 * @param string The dimension restriction type ( 'min' | 'max' )
	 * @return void
	 */
	applyDimRestriction: function( coords, val, direction, bounds, type ) {
		var check;
		if( type == 'min' ) check = ( ( coords.a2 - coords.a1 ) < val );
		else check = ( ( coords.a2 - coords.a1 ) > val );
		if( check ) {
			if( direction == 1 ) coords.a2 = coords.a1 + val;
			else coords.a1 = coords.a2 - val;
			
			// make sure we're still in the bounds (not too pretty for the user, but needed)
			if( coords.a1 < bounds.min ) {
				coords.a1 = bounds.min;
				coords.a2 = val;
			} else if( coords.a2 > bounds.max ) {
				coords.a1 = bounds.max - val;
				coords.a2 = bounds.max;
			}
		}
	},
		
	/**
	 * Applies the supplied ratio to the supplied coordinates
	 * 
	 * @access private
	 * @param obj Coordinates, x1, y1, x2, y2
	 * @param obj Ratio, x, y
	 * @param obj Direction of mouse, x & y : -1 == negative 1 == positive
	 * @param string The current resize handle || null
	 * @return void
	 */
	applyRatio : function( coords, ratio, direction, resizeHandle ) {
		// dump( 'direction.y : ' + direction.y + '\n');
		var newCoords;
		if( resizeHandle == 'N' || resizeHandle == 'S' ) {
			// dump( 'north south \n');
			// if moving on either the lone north & south handles apply the ratio on the y axis
			newCoords = this.applyRatioToAxis( 
				{ a1: coords.y1, b1: coords.x1, a2: coords.y2, b2: coords.x2 },
				{ a: ratio.y, b: ratio.x },
				{ a: direction.y, b: direction.x },
				{ min: 0, max: this.imgW }
			);
			coords.x1 = newCoords.b1;
			coords.y1 = newCoords.a1;
			coords.x2 = newCoords.b2;
			coords.y2 = newCoords.a2;
		} else {
			// otherwise deal with it as if we're applying the ratio on the x axis
			newCoords = this.applyRatioToAxis( 
				{ a1: coords.x1, b1: coords.y1, a2: coords.x2, b2: coords.y2 },
				{ a: ratio.x, b: ratio.y },
				{ a: direction.x, b: direction.y },
				{ min: 0, max: this.imgH }
			);
			coords.x1 = newCoords.a1;
			coords.y1 = newCoords.b1;
			coords.x2 = newCoords.a2;
			coords.y2 = newCoords.b2;
		}
		
	},
	
	/**
	 * Applies the provided ratio to the provided coordinates based on provided direction & bounds,
	 * use to encapsulate functionality to make it easy to apply to either axis. This is probably
	 * quite hard to visualise so see the x axis example within applyRatio()
	 * 
	 * Example in parameter details & comments is for requesting applying ratio to x axis.
	 * 
	 * @access private
	 * @param obj Coords object (a1, b1, a2, b2) where a = x & b = y in example
	 * @param obj Ratio object (a, b) where a = x & b = y in example
	 * @param obj Direction object (a, b) where a = x & b = y in example
	 * @param obj Bounds (min, max)
	 * @return obj Coords object (a1, b1, a2, b2) where a = x & b = y in example
	 */
	applyRatioToAxis: function( coords, ratio, direction, bounds ) {
		var newCoords = Object.extend( coords, {} );
		var calcDimA = newCoords.a2 - newCoords.a1;			// calculate dimension a (e.g. width)
		var targDimB = Math.floor( calcDimA * ratio.b / ratio.a );	// the target dimension b (e.g. height)
		var targB;											// to hold target b (e.g. y value)
		var targDimA;                                		// to hold target dimension a (e.g. width)
		var calcDimB = null;								// to hold calculated dimension b (e.g. height)
		
		// dump( 'newCoords[0]: ' + newCoords.a1 + ',' + newCoords.b1 + ','+ newCoords.a2 + ',' + newCoords.b2 + '\n');
				
		if( direction.b == 1 ) {							// if travelling in a positive direction
			// make sure we're not going out of bounds
			targB = newCoords.b1 + targDimB;
			if( targB > bounds.max ) {
				targB = bounds.max;
				calcDimB = targB - newCoords.b1;			// calcuate dimension b (e.g. height)
			}
			
			newCoords.b2 = targB;
		} else {											// if travelling in a negative direction
			// make sure we're not going out of bounds
			targB = newCoords.b2 - targDimB;
			if( targB < bounds.min ) {
				targB = bounds.min;
				calcDimB = targB + newCoords.b2;			// calcuate dimension b (e.g. height)
			}
			newCoords.b1 = targB;
		}
		
		// dump( 'newCoords[1]: ' + newCoords.a1 + ',' + newCoords.b1 + ','+ newCoords.a2 + ',' + newCoords.b2 + '\n');
			
		// apply the calculated dimensions
		if( calcDimB != null ) {
			targDimA = Math.floor( calcDimB * ratio.a / ratio.b );
			
			if( direction.a == 1 ) newCoords.a2 = newCoords.a1 + targDimA;
			else newCoords.a1 = newCoords.a1 = newCoords.a2 - targDimA;
		}
		
		// dump( 'newCoords[2]: ' + newCoords.a1 + ',' + newCoords.b1 + ','+ newCoords.a2 + ',' + newCoords.b2 + '\n');
			
		return newCoords;
	},
	
	/**
	 * Draws the select area
	 * 
	 * @access private
	 * @return void
	 */
	drawArea: function( ) {	
		/*
		 * NOTE: I'm not using the Element.setStyle() shortcut as they make it 
		 * quite sluggish on Mac based browsers
		 */
		// dump( 'drawArea        : ' + this.areaCoords.x1 + ',' + this.areaCoords.y1 + ',' + this.areaCoords.x2 + ',' + this.areaCoords.y2 + '\n' );
		var areaWidth     = this.calcW();
		var areaHeight    = this.calcH();
		
		/*
		 * Calculate all the style strings before we use them, allows reuse & produces quicker
		 * rendering (especially noticable in Mac based browsers)
		 */
		var px = 'px';
		var params = [
			this.areaCoords.x1 + px, 	// the left of the selArea
			this.areaCoords.y1 + px,		// the top of the selArea
			areaWidth + px,					// width of the selArea
			areaHeight + px,					// height of the selArea
			this.areaCoords.x2 + px,		// bottom of the selArea
			this.areaCoords.y2 + px,		// right of the selArea
			(this.img.width - this.areaCoords.x2) + px,	// right edge of selArea
			(this.img.height - this.areaCoords.y2) + px	// bottom edge of selArea
		];
				
		// do the select area
		var areaStyle				= this.selArea.style;
		areaStyle.left				= params[0];
		areaStyle.top				= params[1];
		areaStyle.width				= params[2];
		areaStyle.height			= params[3];
			  	
		// position the north, east, south & west handles
		var horizHandlePos = Math.ceil( (areaWidth - 6) / 2 ) + px;
		var vertHandlePos = Math.ceil( (areaHeight - 6) / 2 ) + px;
		
		this.handleN.style.left 	= horizHandlePos;
		this.handleE.style.top 		= vertHandlePos;
		this.handleS.style.left 	= horizHandlePos;
		this.handleW.style.top		= vertHandlePos;
		
		// draw the four overlays
		this.north.style.height 	= params[1];
		
		var eastStyle 				= this.east.style;
		eastStyle.top				= params[1];
		eastStyle.height			= params[3];
		eastStyle.left				= params[4];
	    eastStyle.width				= params[6];
	   
	   	var southStyle 				= this.south.style;
	   	southStyle.top				= params[5];
	   	southStyle.height			= params[7];
	   
	    var westStyle       		= this.west.style;
	    westStyle.top				= params[1];
	    westStyle.height			= params[3];
	   	westStyle.width				= params[0];
	   	
		// call the draw method on sub classes
		this.subDrawArea();
		
		this.forceReRender();
	},
	
	/**
	 * Force the re-rendering of the selArea element which fixes rendering issues in Safari 
	 * & IE PC, especially evident when re-sizing perfectly vertical using any of the south handles
	 * 
	 * @access private
	 * @return void
	 */
	forceReRender: function() {
		if( this.isIE || this.isWebKit) {
			var n = document.createTextNode(' ');
			var d,el,fixEL,i;
		
			if( this.isIE ) fixEl = this.selArea;
			else if( this.isWebKit ) {
				fixEl = document.getElementsByClassName( 'imgCrop_marqueeSouth', this.imgWrap )[0];
				/* we have to be a bit more forceful for Safari, otherwise the the marquee &
				 * the south handles still don't move
				 */ 
				d = Builder.node( 'div', '' );
				d.style.visibility = 'hidden';
				
				var classList = ['SE','S','SW'];
				for( i = 0; i < classList.length; i++ ) {
					el = document.getElementsByClassName( 'imgCrop_handle' + classList[i], this.selArea )[0];
					if( el.childNodes.length ) el.removeChild( el.childNodes[0] );
					el.appendChild(d);
				}
			}
			fixEl.appendChild(n);
			fixEl.removeChild(n);
		}
	},
	
	/**
	 * Starts the resize
	 * 
	 * @access private
	 * @param obj Event
	 * @return void
	 */
	startResize: function( e ) {
		this.startCoords = this.cloneCoords( this.areaCoords );
		
		this.resizing = true;
		this.resizeHandle = Event.element( e ).classNames().toString().replace(/([^N|NE|E|SE|S|SW|W|NW])+/, '');
		// dump( 'this.resizeHandle : ' + this.resizeHandle + '\n' );
		Event.stop( e );
	},
	
	/**
	 * Starts the drag
	 * 
	 * @access private
	 * @param obj Event
	 * @return void
	 */
	startDrag: function( e ) {	
		this.selArea.show();
		this.clickCoords = this.getCurPos( e );
     	
    	this.setAreaCoords( { x1: this.clickCoords.x, y1: this.clickCoords.y, x2: this.clickCoords.x, y2: this.clickCoords.y }, false, false, null );
    	
    	this.dragging = true;
    	this.onDrag( e ); // incase the user just clicks once after already making a selection
    	Event.stop( e );
	},
	
	/**
	 * Gets the current cursor position relative to the image
	 * 
	 * @access private
	 * @param obj Event
	 * @return obj x,y pixels of the cursor
	 */
	getCurPos: function( e ) {
		// get the offsets for the wrapper within the document
		var el = this.imgWrap, wrapOffsets = Position.cumulativeOffset( el );
		// remove any scrolling that is applied to the wrapper (this may be buggy) - don't count the scroll on the body as that won't affect us
		while( el.nodeName != 'BODY' ) {
			wrapOffsets[1] -= el.scrollTop  || 0;
			wrapOffsets[0] -= el.scrollLeft || 0;
			el = el.parentNode;
	    }		
		return curPos = { 
			x: Event.pointerX(e) - wrapOffsets[0],
			y: Event.pointerY(e) - wrapOffsets[1]
		}
	},
  	
  	/**
  	 * Performs the drag for both resize & inital draw dragging
  	 * 
  	 * @access private
	 * @param obj Event
	 * @return void
	 */
  	onDrag: function( e ) {
  		if( this.dragging || this.resizing ) {	
  		
  			var resizeHandle = null;
  			var curPos = this.getCurPos( e );			
			var newCoords = this.cloneCoords( this.areaCoords );
  			var direction = { x: 1, y: 1 };
  	  					
		    if( this.dragging ) {
		    	if( curPos.x < this.clickCoords.x ) direction.x = -1;
		    	if( curPos.y < this.clickCoords.y ) direction.y = -1;
		    	
				this.transformCoords( curPos.x, this.clickCoords.x, newCoords, 'x' );
				this.transformCoords( curPos.y, this.clickCoords.y, newCoords, 'y' );
			} else if( this.resizing ) {
				resizeHandle = this.resizeHandle;			
				// do x movements first
				if( resizeHandle.match(/E/) ) {
					// if we're moving an east handle
					this.transformCoords( curPos.x, this.startCoords.x1, newCoords, 'x' );	
					if( curPos.x < this.startCoords.x1 ) direction.x = -1;
				} else if( resizeHandle.match(/W/) ) {
					// if we're moving an west handle
					this.transformCoords( curPos.x, this.startCoords.x2, newCoords, 'x' );
					if( curPos.x < this.startCoords.x2 ) direction.x = -1;
				}
									
				// do y movements second
				if( resizeHandle.match(/N/) ) {
					// if we're moving an north handle	
					this.transformCoords( curPos.y, this.startCoords.y2, newCoords, 'y' );
					if( curPos.y < this.startCoords.y2 ) direction.y = -1;
				} else if( resizeHandle.match(/S/) ) {
					// if we're moving an south handle
					this.transformCoords( curPos.y, this.startCoords.y1, newCoords, 'y' );	
					if( curPos.y < this.startCoords.y1 ) direction.y = -1;
				}	
							
			}
		
			this.setAreaCoords( newCoords, false, e.shiftKey, direction, resizeHandle );
			this.drawArea();
			Event.stop( e ); // stop the default event (selecting images & text) in Safari & IE PC
		}
	},
	
	/**
	 * Applies the appropriate transform to supplied co-ordinates, on the
	 * defined axis, depending on the relationship of the supplied values
	 * 
	 * @access private
	 * @param int Current value of pointer
	 * @param int Base value to compare current pointer val to
	 * @param obj Coordinates to apply transformation on x1, x2, y1, y2
	 * @param string Axis to apply transformation on 'x' || 'y'
	 * @return void
	 */
	transformCoords : function( curVal, baseVal, coords, axis ) {
		var newVals = [ curVal, baseVal ];
		if( curVal > baseVal ) newVals.reverse();
		coords[ axis + '1' ] = newVals[0];
		coords[ axis + '2' ] = newVals[1];		
	},
	
	/**
	 * Ends the crop & passes the values of the select area on to the appropriate 
	 * callback function on completion of a crop
	 * 
	 * @access private
	 * @return void
	 */
	endCrop : function() {
		this.dragging = false;
		this.resizing = false;
		
		this.options.onEndCrop(
			this.areaCoords,
			{
				width: this.calcW(), 
				height: this.calcH() 
			}
		);
	},
	
	/**
	 * Abstract method called on the end of initialization
	 * 
	 * @access private
	 * @abstract
	 * @return void
	 */
	subInitialize: function() {},
	
	/**
	 * Abstract method called on the end of drawArea()
	 * 
	 * @access private
	 * @abstract
	 * @return void
	 */
	subDrawArea: function() {}
};




/**
 * Extend the Cropper.Img class to allow for presentation of a preview image of the resulting crop,
 * the option for displayOnInit is always overridden to true when displaying a preview image
 * 
 * Usage:
 * 	@param obj Image element to attach to
 * 	@param obj Optional options:
 * 		- see Cropper.Img for base options
 * 		
 * 		- previewWrap obj
 * 			HTML element that will be used as a container for the preview image		
 */
Cropper.ImgWithPreview = Class.create();

Object.extend( Object.extend( Cropper.ImgWithPreview.prototype, Cropper.Img.prototype ), {
	
	/**
	 * Implements the abstract method from Cropper.Img to initialize preview image settings.
	 * Will only attach a preview image is the previewWrap element is defined and the minWidth
	 * & minHeight options are set.
	 * 
	 * @see Croper.Img.subInitialize
	 */
	subInitialize: function() {
		/**
		 * Whether or not we've attached a preview image
		 * @var boolean
		 */
		this.hasPreviewImg = false;
		if( typeof(this.options.previewWrap) != 'undefined') {
			/**
			 * The preview image wrapper element
			 * @var obj HTML element
			 */
			this.previewWrap 	= $( this.options.previewWrap );
			/**
			 * The preview image element
			 * @var obj HTML IMG element
			 */
			this.previewImg 	= this.img.cloneNode( false );
			// set the ID of the preview image to be unique
			this.previewImg.id	= 'imgCrop_' + this.previewImg.id;
			this.previewWrap.hide();
			
						
			// set the displayOnInit option to true so we display the select area at the same time as the thumbnail
			this.options.displayOnInit = true;

			this.hasPreviewImg 	= true;
			
			this.previewWrap.addClassName( 'imgCrop_previewWrap' );
			
			if(!this.options.resizePreview) {
				this.previewWrap.setStyle(
				 { 
					width: this.options.minWidth + 'px',
					height: this.options.minHeight + 'px'
				 }
				);
			}
			
			this.previewWrap.appendChild( this.previewImg );
		}
	},
	
	/**
	 * Implements the abstract method from Cropper.Img to draw the preview image
	 * 
	 * @see Croper.Img.subDrawArea
	 */
	subDrawArea: function() {
		if( this.hasPreviewImg ) {
			// get the ratio of the select area to the src image
			var calcWidth = this.calcW();
			var calcHeight = this.calcH();
			if(calcWidth == 0 || calcHeight == 0)
			{
				this.previewWrap.hide();
				return;
			}

			var previewDim;
			if(this.options.resizePreview)
			{
				previewDim = this.options.resizePreview({x: calcWidth, y: calcHeight});

				var wrapStyle 	= this.previewWrap.style;
				wrapStyle.width = previewDim.x + "px";
				wrapStyle.height = previewDim.y + "px";
			}
			else
			{
				previewDim = {
					x: this.options.minWidth,
					y: this.options.minHeight
				}
			}

			// ratios for the dimensions of the preview image
			var dimRatio = { 
				x: this.imgW / calcWidth, 
				y: this.imgH / calcHeight 
			}; 

			// ratios for the positions within the preview
			var posRatio = { 
				x: calcWidth / previewDim.x,
				y: calcHeight / previewDim.y
			};
			
			// setting the positions in an obj before apply styles for rendering speed increase
			var calcPos	= {
				w: Math.ceil( previewDim.x * dimRatio.x ) + 'px',
				h: Math.ceil( previewDim.y * dimRatio.y ) + 'px',
				x: '-' + Math.ceil( this.areaCoords.x1 / posRatio.x )  + 'px',
				y: '-' + Math.ceil( this.areaCoords.y1 / posRatio.y ) + 'px'
			}
			
			var previewStyle 	= this.previewImg.style;
			previewStyle.width 	= calcPos.w;
			previewStyle.height	= calcPos.h;
			previewStyle.left	= calcPos.x;
			previewStyle.top	= calcPos.y;
			this.previewWrap.show();
		}
	}
	
});


DebugWindow = function()
{
  this.shown = false;
  this.log_data = [];
  this.hooks = [];
  this.counter = 0;
  this.update = this.update.bind(this);

  this.hashchange_debug = this.hashchange_debug.bind(this);
  UrlHash.observe("debug", this.hashchange_debug);
  this.hashchange_debug();

  this.log("*** Started");
}

DebugWindow.prototype.create_container = function()
{
  if(this.container)
    return;

  var div = document.createElement("DIV");
  div = $(div);
  div.className = "debug-box";
  div.setStyle({position: "fixed", top: "0px", right: "0px", height: "25%", backgroundColor: "#000", fontSize: "100%"});
  document.body.appendChild(div);
  this.container = div;

  this.shown_debug = "";
}

DebugWindow.prototype.destroy_container = function()
{
  if(!this.container)
    return;
  document.body.removeChild(this.container);
  this.container = null;
}

DebugWindow.prototype.log = function(s)
{
  /*
   * Output to the console log, if any.
   *
   * In FF4, this goes to the Web Console.  (It doesn't go to the error console; it should.)
   * On Android, this goes to logcat.
   * On iPhone, this goes to the intrusive Debug Console if it's turned on (no way to redirect
   * it outside of the phone).
   */
  if(window.console && window.console.log)
    console.log(s);

  ++this.counter;
  this.log_data.push(this.counter + ": " + s);
  var lines = 10;
  if(this.log_data.length > lines)
    this.log_data = this.log_data.slice(1, lines+1);
  if(this.shown)
    this.update.defer();
}

DebugWindow.prototype.hashchange_debug = function()
{
  var debug = UrlHash.get("debug");
  if(debug == null)
    debug = "0";
  debug = (debug == "1");

  if(debug == this.shown)
    return;

  this.shown = debug;
  if(debug)
    this.create_container();
  else
    this.destroy_container();

  this.update();
}

DebugWindow.prototype.add_hook = function(func)
{
  this.hooks.push(func);
}

DebugWindow.prototype.update = function()
{
  if(!this.container)
    return;

  var s = "";
  for(var i = 0; i < this.hooks.length; ++i)
  {
    var func = this.hooks[i];
    s += func() + "<br>";
  }
  s += this.log_data.join("<br>");

  if(s == this.shown_debug)
    return;

  this.shown_debug = s;
  this.container.update(s);
}

/*
 * Return a function, debug(), which logs to a debug window.  The actual debug
 * handler is an attribute of the function.
 *
 * var debug = NewDebug();
 * debug("text");
 * debug.handler.add_hook();
 */
NewDebug = function()
{
  var debug_handler = new DebugWindow();
  var debug = debug_handler.log.bind(debug_handler);
  debug.handler = debug_handler;
  return debug;
}



Dmail = {
  respond: function(to) {
    $("dmail_to_name").value = to
    var stripped_body = $("dmail_body").value.replace(/\[quote\](?:.|\n)+?\[\/quote\]\n*/gm, "")
    $("dmail_body").value = "[quote]You said:\n" + stripped_body + "\n[/quote]\n\n"
    $("response").show()
  },

  expand: function(parent_id, id) {
    notice("Fetching previous messages...")
    
    new Ajax.Updater('previous-messages', '/dmail/show_previous_messages', {
      method: 'get',
      parameters: {
        "id": id,
        "parent_id": parent_id
      },
      onComplete: function() {
        $('previous-messages').show()
        notice("Previous messages loaded")
      }
    })
  }
}


Favorite = {
  link_to_users: function(users) {
    var html = ""
    
    if (users.size() == 0) {
      return "no one"
    } else {
       html = users.slice(0, 6).map(function(x) {return '<a href="/user/show/' + x.id + '">' + x.name + '</a>'}).join(", ")

      if (users.size() > 6) {
        html += '<span id="remaining-favs" style="display: none;">' + users.slice(6, -1).map(function(x) {return '<a href="/user/show/' + x.id + '+order%3Avote">' + x.name + '</a>'}).join(", ") + '</span> <span id="remaining-favs-link">(<a href="#" onclick="$(\'remaining-favs\').show(); $(\'remaining-favs-link\').hide(); return false;">' + (users.size() - 6) + ' more</a>)</span>'
      }
      
      return html
    }
  }
}


Forum = {
  mark_all_read: function() {
    new Ajax.Request("/forum/mark_all_read", {
      onComplete: function() {
        $$("span.forum-topic").invoke("removeClassName", "unread-topic")
        $$("div.forum-update").invoke("removeClassName", "forum-update")
        main_menu.mark_forum_posts_read();
        notice("Marked all topics as read")
      }
    })
  },
  quote: function(id) {
    new Ajax.Request("/forum/show.json", {
      method: 'get',
      parameters: {
        "id": id
      },
      onSuccess: function(resp) {
        var resp = resp.responseJSON
        $('reply').show()
        var stripped_body = resp.body.replace(/\[quote\](?:.|\n|\r)+?\[\/quote\][\n\r]*/gm, "")
        $('forum_post_body').value += '[quote]' + resp.creator + ' said:\n' + stripped_body + '\n[/quote]\n\n'
        if($("respond-link"))
          $("respond-link").hide();
        if($("forum_post_body"))
          $("forum_post_body").focus();
      },
      onFailure: function(req) {
        notice("Error quoting forum post")
      }
    })
  }
}


History = {
  last_click: -1,
  checked: [],
  dragging: false,

  init: function() {
    // Watch mousedown events on the table itself, so clicking between table rows and dragging
    // doesn't misbehave.
    $("history").observe("mousedown", function(event) {
      if (!event.shiftKey) {
        // Clear last_click, so dragging will extend from the next position crossed instead of
        // the previous position clicked.
        History.last_click = -1
      }

      History.mouse_is_down();
      event.stopPropagation();
      event.preventDefault();
    }, true)
    History.update()
  },

  /* change_id is the display column. XXX no */
  add_change: function(change_id, group_by_type, group_by_id, ids, user_id) {
    History.checked.push({
      id: change_id,
      ids: ids,
      group_by_type: group_by_type,
      group_by_id: group_by_id,
      user_id: user_id,
      on: false,
      row: $("r" + change_id)
    })
    $("r" + change_id).observe("mousedown", function(e) { History.mousedown(change_id, e), true })
    $("r" + change_id).observe("mouseover", function(e) { History.mouseover(change_id, e), true })
    if($("r" + change_id).down(".id"))
      $("r" + change_id).down(".id").observe("click", function(event) { History.id_click(change_id) });
    $("r" + change_id).down(".author").observe("click", function(event) { History.author_click(change_id) });
    $("r" + change_id).down(".change").observe("click", function(event) { History.change_click(change_id) });
  },

  update: function() {
    // Set selected flags on selected rows, and remove them from unselected rows.
    for (i = 0; i < History.checked.length; ++i) {
      var row = History.checked[i].row

      if(History.checked[i].on) {
        row.addClassName("selected");
      } else {
        row.removeClassName("selected");
      }
    }

    if (History.count_selected() > 0) {
      $("undo").removeClassName("footer-disabled");
      $("redo").removeClassName("footer-disabled");
    } else {
      $("undo").addClassName("footer-disabled");
      $("redo").addClassName("footer-disabled");
    }
  },

  id_click: function(id, event) {
    id = History.get_row_by_id(id);
    $("search").value = History.checked[id].group_by_type.toLowerCase() + ":" + History.checked[id].group_by_id
  },

  author_click: function(id, event) {
    id = History.get_row_by_id(id);
    $("search").value = "user:" + History.checked[id].user_id
  },

  change_click: function(id, event) {
    id = History.get_row_by_id(id);
    $("search").value = "change:" + History.checked[id].id
  },

  // Return the number of selected items.
  count_selected: function() {
    ret = 0
    for (i = 0; i < History.checked.length; ++i) {
      if (History.checked[i].on)
        ++ret
    }
    return ret;
  },

  // Get the index of the first selected item.
  get_first_selected_row: function() {
    for (i = 0; i < History.checked.length; ++i) {
      if (History.checked[i].on)
        return i;
    }
    return null;
  },

  // Get the index of the item with the specified id.
  get_row_by_id: function(id) {
    for (i = 0; i < History.checked.length; ++i) {
      if (History.checked[i].id == id)
        return i;
    }
    return -1;
  },

  // Set [first, last] = on.
  set: function(first, last, on) {
    i = first;
    while(true)
    {
      History.checked[i].on = on;

      if(i == last)
        break;

      i += (last > first)? +1:-1;
    }
  },

  doc_mouseup: function(event) {
    History.dragging = false
    document.stopObserving("mouseup", History.doc_mouseup)
  },

  // The mouse is down, so we're dragging; watch mouseup to know when we've let go.
  mouse_is_down: function() {
    History.dragging = true;
    document.observe("mouseup", History.doc_mouseup)
  },

  mousedown: function(id, event) {
    if (!Event.isLeftClick(event)) {
      return;
    }

    History.mouse_is_down()

    var i = History.get_row_by_id(id)
    if (i == -1) {
      return;
    }

    var first = null
    var last = null
    if (History.last_click != -1 && event.shiftKey) {
      first = History.last_click
      last = i
    } else {
      first = last = History.last_click = i
      History.checked[i].on = !History.checked[i].on;
    }

    var on = History.checked[first].on

    if (!event.ctrlKey) {
      History.set(0, History.checked.length-1, false)
    }
    History.set(first, last, on)
    History.update()

    event.stopPropagation();
    event.preventDefault();
  },

  mouseover: function(id, event) {
    var i = History.get_row_by_id(id)
    if (i==-1) return;

    if (History.last_click == -1) {
      History.last_click = i
    }

    if (!History.dragging) {
      return;
    }

    History.set(0, History.checked.length-1, false)

    first = History.last_click
    last = i
    this_click = i

    History.set(first, last, true)
    History.update()
  },

  undo: function(redo) {
    if (History.count_selected() == 0) {
      return;
    }
    var list = []
    for (i = 0; i < History.checked.length; ++i) {
      if (!History.checked[i].on)
        continue;
      list = list.concat(History.checked[i].ids)
    }

    if(redo)
      notice("Reapplying...");
    else
      notice("Undoing...");

    new Ajax.Request("/history/undo.json", {
      parameters: {
        "id": list.join(","),
        "redo": redo? 1:0
      },

      onComplete: function(resp) {
        var resp = resp.responseJSON

        if (resp.success) {
          var text = resp.errors;
          if(resp.successful > 0)
            text.unshift(redo? "Changes reapplied.":"Changes undone.");
          notice(text.join("<br>"));
        } else {
          notice("Error: " + resp.reason)
        }
      }
    })
  }
}


InlineImage = {
  mouse_down: null,
  zoom_levels:
  [
    1.0, 1.5, 2.0, 4.0
  ],
  get_zoom: function(level)
  {
    if(level >= 0)
      return InlineImage.zoom_levels[level];
    else
      return 1 / InlineImage.zoom_levels[-level];
  },

  register: function(id, data)
  {
    var container = $(id);
    data.html_id = id;
    container.inline_image = data;
    
    /* initted is set to true after the image has been opened and the large images
     * inside have been created by expand(). */
    data.initted = false;
    data.expanded = false;
    data.toggled_from = null;
    data.current = -1;
    data.zoom_level = 0;

    {
      var ui_html = "";
      if(data.images.length > 1)
      {
        for(var idx = 0; idx < data.images.length; ++idx)
        {
          // html_id looks like "inline-123-456".  Mark the button for each individual image as "inline-123-456-2".
          var button_id = data.html_id + "-" + idx;
          var text = data.images[idx].description.escapeHTML();
          if(text == "")
            text = "#" + (idx + 1);

          ui_html += "<a href='#' id='" + button_id + "' class='select-image' onclick='InlineImage.show_image_no(\"" + data.html_id + "\", " + idx + "); return false;'>" + text + "</a>";
        }
      }
      ui_html += "<a href='#' class='select-image' onclick='InlineImage.zoom(\"" + data.html_id + "\", +1); return false;'>+</a>";
      ui_html += "<a href='#' class='select-image' onclick='InlineImage.zoom(\"" + data.html_id + "\", -1); return false;'>-</a>";
      var zoom_id = data.html_id + "-zoom";
      ui_html += "<a href='#' id='" + zoom_id + "' class='select-image' onclick='InlineImage.zoom(\"" + data.html_id + "\", 0); return false;'>100%</a>";
      ui_html += "<a href='#' class='select-image' onclick='InlineImage.close(\"" + data.html_id + "\"); return false;'>Close</a>";

      ui_html += "<a href='/inline/edit/" + data.id + "' class='edit-link'>Image&nbsp;#" + data.id + "</a>";

      container.down(".expanded-image-ui").innerHTML = ui_html;
    }

    container.down(".inline-thumb").observe("click", function(e) {
      e.stop();
      InlineImage.expand(data.html_id);
    });
    container.observe("dblclick", function(e) {
      e.stop();
    });

    var viewer_img = container.down(".main-inline-image");

    /* If the expanded image has more than one image to choose from, clicking it will
     * temporarily show the next image.  Only show a pointer cursor if this is available. */
    if(data.images.length > 1)
      viewer_img.addClassName("clickable");

    viewer_img.observe("mousedown", function(e) {
      if(e.button != 0)
        return;

      data.toggled_from = data.current;
      var idx = (data.current + 1) % data.images.length;
      InlineImage.show_image_no(data.html_id, idx);
      InlineImage.mouse_down = data;

      /* We need to stop the event, so dragging the mouse after clicking won't turn it
       * into a drag in Firefox.  If that happens, we won't get the mouseup. */
      e.stop();
    });
  },

  init: function()
  {
    /* Mouseup events aren't necessarily sent to the same element that received the mousedown,
     * so we need to track which element received a mousedown and handle mouseup globally. */
    document.observe("mouseup", function(e) {
      if(e.button != 0)
        return;
      if(InlineImage.mouse_down == null)
        return;
      e.stop();
      var data = InlineImage.mouse_down;
      InlineImage.mouse_down = null;

      InlineImage.show_image_no(data.html_id, data.toggled_from);
      data.toggled_from = null;
    });

  },

  expand: function(id)
  {
    var container = $(id);
    var data = container.inline_image;
    data.expanded = true;

    if(!data.initted)
    {
      data.initted = true;
      var images = data["images"];

      var img_html = "";
      for(var idx = 0; idx < data.images.length; ++idx)
      {
        var image = images[idx];
        var width, height, src;
        if(image["sample_width"])
        {
          src = image["sample_url"];
        } else {
          src = image["file_url"];
        }

        var img_id = data.html_id + "-img-" + idx;
        img_html += "<img src='" + src + "' id='" + img_id + "' width=" + width + " height=" + height + " style='display: none;'>";
      }

      var viewer_img = container.down(".main-inline-image");
      viewer_img.innerHTML = img_html;
    }

    container.down(".inline-thumb").hide();
    InlineImage.show_image_no(data.html_id, 0);
    container.down(".expanded-image").show();

    // container.down(".expanded-image").scrollIntoView();
  },

  close: function(id)
  {
    var container = $(id);
    var data = container.inline_image;
    data.expanded = false;
    container.down(".expanded-image").hide();
    container.down(".inline-thumb").show();
  },

  show_image_no: function(id, idx)
  {
    var container = $(id);
    var data = container.inline_image;
    var images = data["images"];
    var image = images[idx];
    var zoom = InlineImage.get_zoom(data.zoom_level);
    
    /* We need to set innerHTML rather than just setting attributes, so the changes happen
     * atomically.  Otherwise, Firefox will apply the width and height changes before source,
     * and flicker the old image at the new image's dimensions. */
    var width, height;
    if(image["sample_width"])
    {
      width = image["sample_width"] * zoom;
      height = image["sample_height"] * zoom;
    } else {
      width = image["width"] * zoom;
      height = image["height"] * zoom;
    }
      width = width.toFixed(0);
      height = height.toFixed(0);

    if(data.current != idx)
    {
      var old_img_id = data.html_id + "-img-" + data.current;
      var old_img = $(old_img_id);
      if(old_img)
        old_img.hide();
    }

    var img_id = data.html_id + "-img-" + idx;
    var img = $(img_id);
    if(img)
    {
      img.width = width;
      img.height = height;
      img.show();
    }

    if(data.current != idx)
    {
      var new_button = $(data.html_id + "-" + idx);
      if(new_button)
        new_button.addClassName("selected-image-tab");

      var old_button = $(data.html_id + "-" + data.current);
      if(old_button)
        old_button.removeClassName("selected-image-tab");

      data.current = idx;
    }
  },

  zoom: function(id, dir)
  {
    var container = $(id);
    var data = container.inline_image;
    if(dir == 0)
      data.zoom_level = 0; // reset
    else
      data.zoom_level += dir;

    if(data.zoom_level > InlineImage.zoom_levels.length - 1)
      data.zoom_level = InlineImage.zoom_levels.length - 1;
    if(data.zoom_level < -InlineImage.zoom_levels.length + 1)
      data.zoom_level = -InlineImage.zoom_levels.length + 1;

    /* Update the zoom level. */
    var zoom_id = data.html_id + "-zoom";
    var zoom = InlineImage.get_zoom(data.zoom_level) * 100;
    $(zoom_id).update(zoom.toFixed(0) + "%");

    InlineImage.show_image_no(id, data.current);
  }

}


var align_element_to_menu = function(submenu, menu_item_elem)
{
  /* Align the top of the dropdown to the bottom-left of the menu link. */
  var offset = menu_item_elem.cumulativeOffset();
  var left = offset.left - 3;

  {
    /* If this would result in the menu falling off the right side of the screen,
     * push it left. */
    var right_edge = submenu.offsetWidth + offset.left;
    var right_overlap = right_edge - document.body.offsetWidth;
    if(right_overlap > 0)
      left -= right_overlap;
  }

  submenu.style.left = left + "px";

  /* offset.top is the top of the menu item text. */
  var bottom = offset.top;

  /* We want to align to the bottom, not the top, so add the height of the text. */
  if(menu_item_elem.getBoundingClientRect)
  {
    /* This is needed in Chrome, where the scrollHeight of our text item is always 0. */
    var height = menu_item_elem.getBoundingClientRect().bottom - menu_item_elem.getBoundingClientRect().top;
    bottom += height;
  }
  else
  {
    bottom += menu_item_elem.scrollHeight;
  }
  submenu.style.top = bottom + "px";
}

function MainMenu(container, def)
{
  this.container = container;
  this.def = def;
  this.submenu = null;
  this.shown_def = null;
  this.focused_menu_item = null;
  this.dropdownTimer = null;
  this.dragging = null;
  this.dragging_over = null;

  this.document_mouseup_event = this.document_mouseup.bindAsEventListener(this);
  this.document_click_event = this.document_click.bindAsEventListener(this);
  this.mousemove_during_dropdown_timer_event = this.mousemove_during_dropdown_timer.bindAsEventListener(this);
}

MainMenu.prototype.get_elem_for_top_item = function(item)
{
    return this.container.down(".top-item-" + item.name);
}

/* This must be called to initialize the menus. */
MainMenu.prototype.init = function()
{
  for(var i = 0; i < this.def.length; ++i)
  {
    var item = this.def[i];
    var elem = this.get_elem_for_top_item(item);

    /* Remove any empty submenus. */
    if(item.sub && !item.sub.length)
      item.sub = null;

    /* The submenu, if open, is a child of elem.  Bind these events to the top
     * menu link, not to elem.  (We don't really need to do this anymore, but
     * it doesn't hurt.) */
    var a = elem.down("a");

    /* Implement the dropdown timer.  Start counting when the mouse goes down, and stop if
     * the mouse comes up for any reason.  This prevents the dropdown from flickering open
     * every time a top-level link is clicked. */
    a.observe("mousedown", this.top_menu_mousedown.bindAsEventListener(this, item));
    a.observe("click", this.top_menu_click.bindAsEventListener(this));
    a.observe("mouseover", this.top_menu_mouseover.bindAsEventListener(this, item));

    /* IE8 needs this one to prevent dragging: */
    a.observe("dragstart", function(event) { event.stop(); }.bindAsEventListener(this));
  }

  var bound_remove_submenu = this.remove_submenu.bindAsEventListener(this);
  Element.observe(window, "blur", bound_remove_submenu);
  Element.observe(window, "pageshow", bound_remove_submenu);
  Element.observe(window, "pagehide", bound_remove_submenu);
}

MainMenu.prototype.get_submenu = function(name)
{
  for(var i = 0; i < this.def.length; ++i)
  {
    if(this.def[i].name == name)
      return this.def[i];
  }
  return null;
}

MainMenu.prototype.show_submenu = function(parent_menu_element, def)
{
  if(this.shown_def == def)
    return;
  this.remove_submenu();

  if(!def.sub)
  {
    this.shown_def = def;
    return;
  }

  var menu_item_elem = this.get_elem_for_top_item(def);
  menu_item_elem.addClassName("selected-menu");

  this.shown_def = def;

  /* Create the dropdown menu. */
  var html = "";
  var id = "";
  if(def.html_id)
    id = 'id="' + def.html_id + '" ';
  html += "<div " + id + "class='dropdown-menu'>";
        
  for(var i = 0; i < def.sub.length; ++i)
  {
    var item = def.sub[i];

    /* IE8 acts funny if we test item.separator directly when it's undefined. */
    if(item.separator == true)
    {
      html += '<div class="separator"></div>';
      continue;
    }

    var class_names = "submenu";
    class_names += " submenu-item-" + i;
    if(item.class_names)
      class_names += " " + item.class_names.join(" ");

    
    html += "<a class='" + class_names + "' href=\"" + (item.dest || "#") + "\">";
    html += item.label.replace(" ", "&nbsp;", "g");
    html += "</a>";
  }
  html += "</div>";

  /* Create the menu. */
  this.submenu = document.createElement("div");
  /* Note that we should be positioning relative to the viewport; our relative parent
   * should be document.body.  However, don't parent our submenu directly to the body,
   * since that breaks on some pages in IE8. */
  this.container.insertBefore(this.submenu, this.container.firstChild);
  $(this.submenu).replace(html);
  this.submenu = this.container.down(".dropdown-menu");

  align_element_to_menu(this.submenu, menu_item_elem);

  var bound_remove_submenu = this.remove_submenu.bind(this);
  var menu_item_mouseover_event = function(event) {
    this.hovering_over_item(event.target);
  }.bindAsEventListener(this);

  var menu_item_mouseout_event = function(event) {
    this.hovering_over_item(null);
  }.bindAsEventListener(this);

  /* Bind events to the new submenu. */
  for(var i = 0; i < def.sub.length; ++i)
  {
    var elem = this.submenu.down(".submenu-item-" + i);
    if(!elem)
      continue;

    var item = def.sub[i];
    if(item.func)
    {
      elem.observe("click", function(event, item)
      {
        event.stop();
        item.func(event, this, def, item);
      }.bindAsEventListener(this, item));
    }

    /* If this menu item requires a login, attach the login handler. */
    if(item.login)
      elem.observe("click", User.run_login_onclick);

    /* Keep track of which menu item we're hovering over. */
    elem.observe("mouseover", menu_item_mouseover_event);
    elem.observe("mouseout", menu_item_mouseout_event);
  }
}

MainMenu.prototype.remove_submenu = function()
{
  if(this.submenu)
  {
    this.submenu.parentNode.removeChild(this.submenu);
    this.submenu = null;
  }

  if(this.shown_def)
  {
    var menu_item_elem = this.get_elem_for_top_item(this.shown_def);
    menu_item_elem.removeClassName("selected-menu");
    this.shown_def = null;
  }
}

MainMenu.prototype.stop_dropdown_timer = function()
{
  if(!this.dropdownTimer)
    return;

  clearTimeout(this.dropdownTimer);
  this.dropdownTimer = null;

  document.stopObserving("mousemove", this.mousemove_during_dropdown_timer_event);
}

MainMenu.prototype.hovering_over_item = function(element)
{
  if(this.focused_menu_item)
    this.focused_menu_item.removeClassName("focused-menu-item");

  /* Keep track of which menu item we're hovering over. */
  this.focused_menu_item = element;

  /* Mark the hovered item.  For some reason, :hover CSS rules don't work while
   * a mouse button is depressed in WebKit. */
  if(element)
    element.addClassName("focused-menu-item");
}

/* Stop the drag, either because the mouse button was released or some other
 * event cancelled it.  Close the menu and clean up. */
MainMenu.prototype.stop_drag = function()
{
  if(!this.dragging)
    return;
  this.dragging = null;
  this.dragging_over = null;
  this.hovering_over_item(null);

  document.stopObserving("mouseup", this.document_mouseup_event);
  document.stopObserving("click", this.document_click_event);

  this.stop_dropdown_timer();
  this.remove_submenu();
};

MainMenu.prototype.top_menu_mousedown = function(event, def)
{
  if(!event.isLeftClick())
    return;

  // preventDefault here will stop the mousedown from starting a drag, which will cancel
  // the click in mouse browsers and do other things we don't want.  Don't use stop();
  // if we call stopPropagation we'll also stop clicks.
  event.preventDefault();
      
  /* Stop the previous drag event, which probably shouldn't still be active. */
  this.stop_drag();

  document.observe("mouseup", this.document_mouseup_event);
  document.observe("click", this.document_click_event);

  this.dragging = [event.clientX, event.clientY];
  this.dragging_over = def;

  /* Start the timer before we show the dropdown automatically, and set up the
   * mousemove event to show the dropdown immediately if we're dragged before that
   * happens. */
  document.observe("mousemove", this.mousemove_during_dropdown_timer_event);
  this.dropdownTimer = window.setTimeout(function()
  {
    if(this.dragging_over)
      this.show_submenu(event.target, this.dragging_over);
  }.bind(this), 250);
}

/*
 * We received a click while the mouse was already held down.  This probably means the
 * user right- or middle-clicked a menu item while holding the menu open with the left
 * mouse button.  In this case, let the browser do whatever it's going to do (probably
 * open the menu item in a new window), and simply close the menu so releasing the left
 * button doesn't activate the item a second time.
 *
 * Ordinary menu selections are handled in document_mouseup.
 */
MainMenu.prototype.document_click = function(event)
{
  if(event.isLeftClick())
    return;
  this.stop_drag();
}

MainMenu.prototype.document_mouseup = function(event)
{
  if(!event.isLeftClick())
  {
    /* The user right- or middle-clicked, so we need to close the menu.  We can't
     * do this from onclick, since WebKit doesn't yet send onclick for non-primary
     * buttons.  However, we can't actually remove the menu right now, since that'll
     * cause Gecko to never send the click.  Defer it, so the menu will be closed
     * after the click event finishes. */
    this.stop_drag.bind(this).defer();
    return;
  }

  if(this.dropdownTimer)
  {
    clearTimeout(this.dropdownTimer);
    this.dropdownTimer = null;
  }

  var menu_was_shown = this.shown_def;
  var hovered_menu_item = this.focused_menu_item;
  this.stop_drag();
  if(!menu_was_shown)
    return;

  /* We'll only get this event if the menu was opened.  Prevent the click from
   * occuring if the menu was opened.  Just stopping the event won't do it. */
  event.stop();
  this.cancel_next_click = true;

  /* Tricky: we can't be absolutely certain that this mouseup will result in a
   * click event.  Clear cancel_next_click if the event doesn't arrive. */
  (function() { this.cancel_next_click = false; }.bind(this)).defer();

  if(!hovered_menu_item)
    return;

  /* Simulate a click, so JS anchors work properly. */
  if(document.createEvent)
  {
    var ev = document.createEvent("MouseEvents");
    ev.initMouseEvent("click", true, true, document.defaultView, 1, 0, 0, 0, 0, false, false, false, false, 0, null);
    if(hovered_menu_item.dispatchEvent(ev) && !ev.stopped)
      window.location.href = hovered_menu_item.href;
  }
  else
  {
    /* IE.  Don't use hovered_menu_item.click(); it won't work in IE7. */
    if(hovered_menu_item.fireEvent("onclick"))
      window.location.href = hovered_menu_item.href;
  }
};

MainMenu.prototype.mousemove_during_dropdown_timer = function(event)
{
  event.returnValue = false;
  event.preventDefault();

  if(!this.dropdownTimer)
    return;

  /* If we've dragged downward before the menu is shown, show it. */
  if(event.clientY - this.dragging[1] < 3)
    return;

  /* Dragging opens the dropdown immediately, so stop the dropdown timer if
   * it's running. */
  this.stop_dropdown_timer();

  this.show_submenu(event.target, this.dragging_over);
};

MainMenu.prototype.top_menu_click = function(event)
{
  this.stop_drag();

  if(this.cancel_next_click)
  {
    /* If a click arrives after the dropdown menu was opened, ignore it.  Note that by
     * the time we get here, the dropdown menu will usually have already been closed by
     * mouseup, so we can't just check this.shown_def. */
    this.cancel_next_click = false;
    event.stop();
  }
}

MainMenu.prototype.top_menu_mouseover = function(event, def)
{
  if(this.dragging)
  {
    /* We're dragging, and the mouse moved from one menu item to another before
     * the item was displayed.  Update, so we show the new item. */
    this.dragging_over = def;
  }

  /* If we hover over a top-level menu item while the dropdown is open,
   * show the new menu. */
  if(!this.shown_def)
    return;
  this.show_submenu(event.target, def);
}

MainMenu.prototype.add_forum_posts_to_submenu = function()
{
  var menu = this.get_submenu("forum").sub;
  if(!menu)
    return;

  var forum_posts = Cookie.get("current_forum_posts");
  if(!forum_posts)
    return;
  var forum_posts = forum_posts.evalJSON();
  if(!forum_posts.length)
    return;

  var any_unread = false;
  for(var i = 0; i < forum_posts.length; ++i)
    if(forum_posts[i][2])
      any_unread = true;
  if(any_unread)
    menu.push({ label: "Mark&nbsp;all&nbsp;read", func: Forum.mark_all_read });

  menu.push({ separator: true });

  for(var i = 0; i < forum_posts.length; ++i)
  {
    /* [title, id, unread, last_page_no] */
    var fp = forum_posts[i];
    var dest = "/forum/show/" + fp[1];
    if(parseInt(fp[3]) > "1")
	    dest += "?page=" + fp[3];
    menu.push({
      label: fp[0], dest: dest, class_names: ["forum-topic"]
    });

    /* Bold the item if it's unread. */
    if(fp[2])
      menu[menu.length-1].class_names.push("unread-topic");
  }
}

MainMenu.prototype.mark_forum_posts_read = function()
{
  var menu = this.get_submenu("forum").sub;
  if(!menu)
    return;

  for(var i = 0; i < menu.length; ++i)
  {
    if(!menu[i].class_names)
      continue;
    menu[i].class_names = menu[i].class_names.reject(function(x) { return x == "unread-topic"; });
  }
}

/* This shows a popup search box, contained within container like a submenu, aligned
 * to the specified element (normally a menu item).  The popup will destroy itself when
 * finished. */
function QuickSearch(container, html, align_to)
{
  html = "<div class='dropdown-menu'>" + html + "</div>";

  this.container = container;

  this.hide_event = this.hide_event.bindAsEventListener(this);
  this.on_document_keydown_event = this.on_document_keydown_event.bindAsEventListener(this);
  this.document_mousedown_event = this.document_mousedown_event.bindAsEventListener(this);

  /* Create the contents. */
  this.submenu = document.createElement("div");

  /* Note that we should be positioning relative to the viewport; our relative parent
   * should be document.body.  However, don't parent our submenu directly to the body,
   * since that breaks on some pages in IE8. */
  this.container.insertBefore(this.submenu, this.container.firstChild);
  $(this.submenu).replace(html);
  this.submenu = this.container.down(".dropdown-menu");

  align_element_to_menu(this.submenu, align_to);

  /* We watch for escape presses on the document instead of the element, so even if
   * the element doesn't receive focus for some reason, pressing escape still closes
   * it. */
  document.observe("keydown", this.on_document_keydown_event);
  document.observe("mousedown", this.document_mousedown_event);

  Element.observe(window, "pageshow", this.hide_event);
  Element.observe(window, "pagehide", this.hide_event);

  /* This stuff is specific to the actual content of the box: focus the form, and
   * hide it on submit. */
  this.submenu.down(".default").focus();
  this.submenu.select("form").each(function(e) {
    e.observe("submit", this.hide_event);
  }.bind(this));
}

QuickSearch.prototype.on_document_keydown_event = function(event) {
  if (event.keyCode == Event.KEY_ESC)
    this.hide();
}

QuickSearch.prototype.document_mousedown_event = function(event)
{
  if($(event.target).isParentNode(this.submenu))
    return;
  this.hide();
}

QuickSearch.prototype.hide_event = function(event)
{
  this.hide();
};

QuickSearch.prototype.hide = function()
{
  if(!this.submenu)
    return;

  /* Remove the menu from the document.  We need to work around a FF3.6 bug here: if
   * we simply remove the item from the document while a form dropdown box is open,
   * the dropdown won't disappear.  We need to hide() first to cause it to be dropped,
   * and defer removing the element until after we return in order to let it take
   * effect. */
  this.submenu.hide();
  (function(elem) {
    elem.parentNode.removeChild(elem);
  }).curry(this.submenu).defer();

  this.submenu = null;
  document.stopObserving("keydown", this.on_document_keydown_event);
  document.stopObserving("mousedown", this.document_mousedown_event);
  Element.stopObserving(window, "blur", this.hide_event);
  Element.stopObserving(window, "pageshow", this.hide_event);
  Element.stopObserving(window, "pagehide", this.hide_event);
}

/* Create functions that can be used as the func parameter to a menu item to
 * open quick searches. */
function MakeSearchHandler(search_path, id, submit_button_text)
{
  var ShowSearch = function(event, menu, def, item)
  {
    var html = "";
    html += '<form action="' + search_path + '" method="get">';
    html += '<input id="' + id + '" name="' + id + '" size="30" type="text" class="default">';
    html += '<br>';
    html += '<input style="margin-top: 0.25em;" type="submit" value="' + submit_button_text + '">';
    html += '</form>';

    new QuickSearch(menu.container, html, menu.get_elem_for_top_item(def));
  }
  return ShowSearch;
}

ShowPostSearch = MakeSearchHandler("/post", "tags", "Search posts");
ShowCommentSearch = MakeSearchHandler("/comment/search", "query", "Search comments");
ShowNoteSearch = MakeSearchHandler("/note/search", "query", "Search notes");
ShowArtistSearch = MakeSearchHandler("/artist", "name", "Search artists");
ShowTagSearch = MakeSearchHandler("/tag", "name", "Search tags");
ShowPoolSearch = MakeSearchHandler("/pool", "query", "Search pools");
ShowWikiSearch = MakeSearchHandler("/wiki", "query", "Search wiki");
ShowForumSearch = MakeSearchHandler("/forum/search", "query", "Search forums");



// The following are instance methods and variables
var Note = Class.create({
  initialize: function(id, is_new, raw_body) {
    if (Note.debug) {
      console.debug("Note#initialize (id=%d)", id)
    }
    
    this.id = id
    this.is_new = is_new
    this.document_observers = [];

    // Cache the elements
    this.elements = {
      box: $('note-box-' + this.id),
      corner: $('note-corner-' + this.id),
      body: $('note-body-' + this.id),
      image: $('image')
    }

    // Cache the dimensions
    this.fullsize = {
      left: this.elements.box.offsetLeft,
      top: this.elements.box.offsetTop,
      width: this.elements.box.clientWidth,
      height: this.elements.box.clientHeight
    }
    
    // Store the original values (in case the user clicks Cancel)
    this.old = {
      raw_body: raw_body,
      formatted_body: this.elements.body.innerHTML
    }
    for (p in this.fullsize) {
      this.old[p] = this.fullsize[p]
    }

    // Make the note translucent
    if (is_new) {
      this.elements.box.setOpacity(0.2)
    } else {
      this.elements.box.setOpacity(0.5)      
    }

    if (is_new && raw_body == '') {
      this.bodyfit = true
      this.elements.body.style.height = "100px"
    }

    // Attach the event listeners
    this.elements.box.observe("mousedown", this.dragStart.bindAsEventListener(this))
    this.elements.box.observe("mouseout", this.bodyHideTimer.bindAsEventListener(this))
    this.elements.box.observe("mouseover", this.bodyShow.bindAsEventListener(this))
    this.elements.corner.observe("mousedown", this.resizeStart.bindAsEventListener(this))
    this.elements.body.observe("mouseover", this.bodyShow.bindAsEventListener(this))
    this.elements.body.observe("mouseout", this.bodyHideTimer.bindAsEventListener(this))
    this.elements.body.observe("click", this.showEditBox.bindAsEventListener(this))

    this.adjustScale()
  },

  // Returns the raw text value of this note
  textValue: function() {
    if (Note.debug) {
      console.debug("Note#textValue (id=%d)", this.id)
    }
    
    return this.old.raw_body.strip()
  },

  // Removes the edit box
  hideEditBox: function(e) {
    if (Note.debug) {
      console.debug("Note#hideEditBox (id=%d)", this.id)
    }
      
    var editBox = $('edit-box')

    if (editBox != null) {
      var boxid = editBox.noteid

      $("edit-box").stopObserving()
      $("note-save-" + boxid).stopObserving()
      $("note-cancel-" + boxid).stopObserving()
      $("note-remove-" + boxid).stopObserving()
      $("note-history-" + boxid).stopObserving()
      $("edit-box").remove()
    }
  },

  // Shows the edit box
  showEditBox: function(e) {
    if (Note.debug) {
      console.debug("Note#showEditBox (id=%d)", this.id)
    }
    
    this.hideEditBox(e)

    var insertionPosition = Note.getInsertionPosition()
    var top = insertionPosition[0]
    var left = insertionPosition[1]
    var html = ""

    html += '<div id="edit-box" style="top: '+top+'px; left: '+left+'px; position: absolute; visibility: visible; z-index: 100; background: white; border: 1px solid black; padding: 12px;">'
    html += '<form onsubmit="return false;" style="padding: 0; margin: 0;">'
    html += '<textarea rows="7" id="edit-box-text" style="width: 350px; margin: 2px 2px 12px 2px;">' + this.textValue() + '</textarea>'
    html += '<input type="submit" value="Save" name="save" id="note-save-' + this.id + '">'
    html += '<input type="submit" value="Cancel" name="cancel" id="note-cancel-' + this.id + '">'
    html += '<input type="submit" value="Remove" name="remove" id="note-remove-' + this.id + '">'
    html += '<input type="submit" value="History" name="history" id="note-history-' + this.id + '">'
    html += '</form>'
    html += '</div>'

    $("note-container").insert({bottom: html})
    $('edit-box').noteid = this.id
    $("edit-box").observe("mousedown", this.editDragStart.bindAsEventListener(this))
    $("note-save-" + this.id).observe("click", this.save.bindAsEventListener(this))
    $("note-cancel-" + this.id).observe("click", this.cancel.bindAsEventListener(this))
    $("note-remove-" + this.id).observe("click", this.remove.bindAsEventListener(this))
    $("note-history-" + this.id).observe("click", this.history.bindAsEventListener(this))
    $("edit-box-text").focus()
  },

  // Shows the body text for the note
  bodyShow: function(e) {
    if (Note.debug) {
      console.debug("Note#bodyShow (id=%d)", this.id)
    }
    
    if (this.dragging) {
      return
    }

    if (this.hideTimer) {
      clearTimeout(this.hideTimer)
      this.hideTimer = null
    }

    if (Note.noteShowingBody == this) {
      return
    }
    
    if (Note.noteShowingBody) {
      Note.noteShowingBody.bodyHide()
    }
    
    Note.noteShowingBody = this

    if (Note.zindex >= 9) {
      /* don't use more than 10 layers (+1 for the body, which will always be above all notes) */
      Note.zindex = 0
      for (var i=0; i< Note.all.length; ++i) {
        Note.all[i].elements.box.style.zIndex = 0
      }
    }

    this.elements.box.style.zIndex = ++Note.zindex
    this.elements.body.style.zIndex = 10
    this.elements.body.style.top = 0 + "px"
    this.elements.body.style.left = 0 + "px"

    var dw = document.documentElement.scrollWidth
    this.elements.body.style.visibility = "hidden"
    this.elements.body.style.display = "block"
    if (!this.bodyfit) {
      this.elements.body.style.height = "auto"
      this.elements.body.style.minWidth = "140px"
      var w = null, h = null, lo = null, hi = null, x = null, last = null
      w = this.elements.body.offsetWidth
      h = this.elements.body.offsetHeight
      if (w/h < 1.6180339887) {
        /* for tall notes (lots of text), find more pleasant proportions */
        lo = 140, hi = 400
        do {
          last = w
          x = (lo+hi)/2
          this.elements.body.style.minWidth = x + "px"
          w = this.elements.body.offsetWidth
          h = this.elements.body.offsetHeight
          if (w/h < 1.6180339887) lo = x
          else hi = x
        } while ((lo < hi) && (w > last))
      } else if (this.elements.body.scrollWidth <= this.elements.body.clientWidth) {
        /* for short notes (often a single line), make the box no wider than necessary */  
        // scroll test necessary for Firefox
        lo = 20, hi = w
  
        do {
          x = (lo+hi)/2
          this.elements.body.style.minWidth = x + "px"
          if (this.elements.body.offsetHeight > h) lo = x
          else hi = x
        } while ((hi - lo) > 4)
        if (this.elements.body.offsetHeight > h)
          this.elements.body.style.minWidth = hi + "px"
      }
      
      if (Prototype.Browser.IE) {
        // IE7 adds scrollbars if the box is too small, obscuring the text
        if (this.elements.body.offsetHeight < 35) {
          this.elements.body.style.minHeight = "35px"
        }
        
        if (this.elements.body.offsetWidth < 47) {
          this.elements.body.style.minWidth = "47px"
        }
      }
      this.bodyfit = true
    }
    this.elements.body.style.top = (this.elements.box.offsetTop + this.elements.box.clientHeight + 5) + "px"
    // keep the box within the document's width
    var l = 0, e = this.elements.box
    do { l += e.offsetLeft } while (e = e.offsetParent)
    l += this.elements.body.offsetWidth + 10 - dw
    if (l > 0)
      this.elements.body.style.left = this.elements.box.offsetLeft - l + "px"
    else
      this.elements.body.style.left = this.elements.box.offsetLeft + "px"
    this.elements.body.style.visibility = "visible"
  },

  // Creates a timer that will hide the body text for the note
  bodyHideTimer: function(e) {
    if (Note.debug) {
      console.debug("Note#bodyHideTimer (id=%d)", this.id)
    }
    this.hideTimer = setTimeout(this.bodyHide.bindAsEventListener(this), 250)
  },

  // Hides the body text for the note
  bodyHide: function(e) {
    if (Note.debug) {
      console.debug("Note#bodyHide (id=%d)", this.id)
    }
    
    this.elements.body.hide()
    if (Note.noteShowingBody == this) {
      Note.noteShowingBody = null
    }
  },

  addDocumentObserver: function(name, func)
  {
    document.observe(name, func);
    this.document_observers.push([name, func]);
  },

  clearDocumentObservers: function(name, handler)
  {
    for(var i = 0; i < this.document_observers.length; ++i)
    {
      var observer = this.document_observers[i];
      document.stopObserving(observer[0], observer[1]);
    }

    this.document_observers = [];
  },

  // Start dragging the note
  dragStart: function(e) {
    if (Note.debug) {
      console.debug("Note#dragStart (id=%d)", this.id)
    }
    
    this.addDocumentObserver("mousemove", this.drag.bindAsEventListener(this))
    this.addDocumentObserver("mouseup", this.dragStop.bindAsEventListener(this))
    this.addDocumentObserver("selectstart", function() {return false})

    this.cursorStartX = e.pointerX()
    this.cursorStartY = e.pointerY()
    this.boxStartX = this.elements.box.offsetLeft
    this.boxStartY = this.elements.box.offsetTop
    this.boundsX = new ClipRange(5, this.elements.image.clientWidth - this.elements.box.clientWidth - 5)
    this.boundsY = new ClipRange(5, this.elements.image.clientHeight - this.elements.box.clientHeight - 5)
    this.dragging = true
    this.bodyHide()
  },

  // Stop dragging the note
  dragStop: function(e) {
    if (Note.debug) {
      console.debug("Note#dragStop (id=%d)", this.id)
    }
    
    this.clearDocumentObservers()

    this.cursorStartX = null
    this.cursorStartY = null
    this.boxStartX = null
    this.boxStartY = null
    this.boundsX = null
    this.boundsY = null
    this.dragging = false

    this.bodyShow()
  },

  ratio: function() {
    return this.elements.image.width / this.elements.image.getAttribute("large_width")
    // var ratio = this.elements.image.width / this.elements.image.getAttribute("large_width")
    // if (this.elements.image.scale_factor != null)
      // ratio *= this.elements.image.scale_factor;
    // return ratio
  },

  // Scale the notes for when the image gets resized
  adjustScale: function() {
    if (Note.debug) {
      console.debug("Note#adjustScale (id=%d)", this.id)
    }
    
    var ratio = this.ratio()
    for (p in this.fullsize) {
      this.elements.box.style[p] = this.fullsize[p] * ratio + 'px'
    }
  },

  // Update the note's position as it gets dragged
  drag: function(e) {
    var left = this.boxStartX + e.pointerX() - this.cursorStartX
    var top = this.boxStartY + e.pointerY() - this.cursorStartY
    left = this.boundsX.clip(left)
    top = this.boundsY.clip(top)

    this.elements.box.style.left = left + 'px'
    this.elements.box.style.top = top + 'px'
    var ratio = this.ratio()
    this.fullsize.left = left / ratio
    this.fullsize.top = top / ratio

    e.stop()
  },
  
  // Start dragging the edit box
  editDragStart: function(e) {
    if (Note.debug) {
      console.debug("Note#editDragStart (id=%d)", this.id)
    }
    
    var node = e.element().nodeName
    if (node != 'FORM' && node != 'DIV') {
      return
    }

    this.addDocumentObserver("mousemove", this.editDrag.bindAsEventListener(this))
    this.addDocumentObserver("mouseup", this.editDragStop.bindAsEventListener(this))
    this.addDocumentObserver("selectstart", function() {return false})

    this.elements.editBox = $('edit-box');
    this.cursorStartX = e.pointerX()
    this.cursorStartY = e.pointerY()
    this.editStartX = this.elements.editBox.offsetLeft
    this.editStartY = this.elements.editBox.offsetTop
    this.dragging = true
  },

  // Stop dragging the edit box
  editDragStop: function(e) {
    if (Note.debug) {
      console.debug("Note#editDragStop (id=%d)", this.id)
    }
    this.clearDocumentObservers()

    this.cursorStartX = null
    this.cursorStartY = null
    this.editStartX = null
    this.editStartY = null
    this.dragging = false
  },

  // Update the edit box's position as it gets dragged
  editDrag: function(e) {
    var left = this.editStartX + e.pointerX() - this.cursorStartX
    var top = this.editStartY + e.pointerY() - this.cursorStartY

    this.elements.editBox.style.left = left + 'px'
    this.elements.editBox.style.top = top + 'px'

    e.stop()
  },

  // Start resizing the note
  resizeStart: function(e) {
    if (Note.debug) {
      console.debug("Note#resizeStart (id=%d)", this.id)
    }
    
    this.cursorStartX = e.pointerX()
    this.cursorStartY = e.pointerY()
    this.boxStartWidth = this.elements.box.clientWidth
    this.boxStartHeight = this.elements.box.clientHeight
    this.boxStartX = this.elements.box.offsetLeft
    this.boxStartY = this.elements.box.offsetTop
    this.boundsX = new ClipRange(10, this.elements.image.clientWidth - this.boxStartX - 5)
    this.boundsY = new ClipRange(10, this.elements.image.clientHeight - this.boxStartY - 5)
    this.dragging = true

    this.clearDocumentObservers()
    this.addDocumentObserver("mousemove", this.resize.bindAsEventListener(this))
    this.addDocumentObserver("mouseup", this.resizeStop.bindAsEventListener(this))
    
    e.stop()
    this.bodyHide()
  },

  // Stop resizing teh note
  resizeStop: function(e) {
    if (Note.debug) {
      console.debug("Note#resizeStop (id=%d)", this.id)
    }
    
    this.clearDocumentObservers()

    this.boxCursorStartX = null
    this.boxCursorStartY = null
    this.boxStartWidth = null
    this.boxStartHeight = null
    this.boxStartX = null
    this.boxStartY = null
    this.boundsX = null
    this.boundsY = null
    this.dragging = false

    e.stop()
  },

  // Update the note's dimensions as it gets resized
  resize: function(e) {
    var width = this.boxStartWidth + e.pointerX() - this.cursorStartX
    var height = this.boxStartHeight + e.pointerY() - this.cursorStartY
    width = this.boundsX.clip(width)
    height = this.boundsY.clip(height)

    this.elements.box.style.width = width + "px"
    this.elements.box.style.height = height + "px"
    var ratio = this.ratio()
    this.fullsize.width = width / ratio
    this.fullsize.height = height / ratio

    e.stop()
  },

  // Save the note to the database
  save: function(e) {
    if (Note.debug) {
      console.debug("Note#save (id=%d)", this.id)
    }
    
    var note = this
    for (p in this.fullsize) {
      this.old[p] = this.fullsize[p]
    }
    this.old.raw_body = $('edit-box-text').value
    this.old.formatted_body = this.textValue()
    // FIXME: this is not quite how the note will look (filtered elems, <tn>...). the user won't input a <script> that only damages him, but it might be nice to "preview" the <tn> here
    this.elements.body.update(this.textValue())

    this.hideEditBox(e)
    this.bodyHide()
    this.bodyfit = false

    var params = {
      "id": this.id,
      "note[x]": this.old.left,
      "note[y]": this.old.top,
      "note[width]": this.old.width,
      "note[height]": this.old.height,
      "note[body]": this.old.raw_body
    }
    
    if (this.is_new) {
      params["note[post_id]"] = Note.post_id
    }

    notice("Saving note...")

    new Ajax.Request('/note/update.json', {
      parameters: params,
      
      onComplete: function(resp) {
        var resp = resp.responseJSON
        
        if (resp.success) {
          notice("Note saved")
          var note = Note.find(resp.old_id)

          if (resp.old_id < 0) {
            note.is_new = false
            note.id = resp.new_id
            note.elements.box.id = 'note-box-' + note.id
            note.elements.body.id = 'note-body-' + note.id
            note.elements.corner.id = 'note-corner-' + note.id
          }
          note.elements.body.innerHTML = resp.formatted_body
          note.elements.box.setOpacity(0.5)
          note.elements.box.removeClassName('unsaved')
        } else {
          notice("Error: " + resp.reason)
          note.elements.box.addClassName('unsaved')
        }
      }
    })

    e.stop()
  },

  // Revert the note to the last saved state
  cancel: function(e) {
    if (Note.debug) {
      console.debug("Note#cancel (id=%d)", this.id)
    }
    
    this.hideEditBox(e)
    this.bodyHide()

    var ratio = this.ratio()
    for (p in this.fullsize) {
      this.fullsize[p] = this.old[p]
      this.elements.box.style[p] = this.fullsize[p] * ratio + 'px'
    }
    this.elements.body.innerHTML = this.old.formatted_body

    e.stop()
  },

  // Remove all references to the note from the page
  removeCleanup: function() {
    if (Note.debug) {
      console.debug("Note#removeCleanup (id=%d)", this.id)
    }
    
    this.elements.box.remove()
    this.elements.body.remove()

    var allTemp = []
    for (i=0; i<Note.all.length; ++i) {
      if (Note.all[i].id != this.id) {
        allTemp.push(Note.all[i])
      }
    }

    Note.all = allTemp
    Note.updateNoteCount()
  },

  // Removes a note from the database
  remove: function(e) {
    if (Note.debug) {
      console.debug("Note#remove (id=%d)", this.id)
    }
    
    this.hideEditBox(e)
    this.bodyHide()
    this_note = this

    if (this.is_new) {
      this.removeCleanup()
      notice("Note removed")

    } else {
      notice("Removing note...")

      new Ajax.Request('/note/update.json', {
        parameters: {
          "id": this.id,
          "note[is_active]": "0"
        },
        onComplete: function(resp) {
          var resp = resp.responseJSON
          
          if (resp.success) {
            notice("Note removed")
            this_note.removeCleanup()
          } else {
            notice("Error: " + resp.reason)
          }
        }
      })
    }

    e.stop()
  },

  // Redirect to the note's history
  history: function(e) {
    if (Note.debug) {
      console.debug("Note#history (id=%d)", this.id)
    }
    
    this.hideEditBox(e)

    if (this.is_new) {
      notice("This note has no history")
    } else {
      location.pathname = '/history?search=notes:' + this.id
    }
    
    e.stop()
  }
})

// The following are class methods and variables
Object.extend(Note, {
  zindex: 0,
  counter: -1,
  all: [],
  display: true,
  debug: false,

  // Show all notes
  show: function() {
    if (Note.debug) {
      console.debug("Note.show")
    }
    
    $("note-container").show()
  },

  // Hide all notes
  hide: function() {
    if (Note.debug) {
      console.debug("Note.hide")
    }

    $("note-container").hide()
  },

  // Find a note instance based on the id number
  find: function(id) {
    if (Note.debug) {
      console.debug("Note.find")
    }
    
    for (var i=0; i<Note.all.size(); ++i) {
      if (Note.all[i].id == id) {
        return Note.all[i]
      }
    }

    return null
  },

  // Toggle the display of all notes
  toggle: function() {
    if (Note.debug) {
      console.debug("Note.toggle")
    }
    
    if (Note.display) {
      Note.hide()
      Note.display = false
    } else {
      Note.show()
      Note.display = true
    }
  },

  // Update the text displaying the number of notes a post has
  updateNoteCount: function() {
    if (Note.debug) {
      console.debug("Note.updateNoteCount")
    }
    
    if (Note.all.length > 0) {
      var label = ""

      if (Note.all.length == 1)
        label = "note"
      else
        label = "notes"

      $('note-count').innerHTML = "This post has <a href=\"/note/history?post_id=" + Note.post_id + "\">" + Note.all.length + " " + label + "</a>"
    } else {
      $('note-count').innerHTML = ""
    }
  },

  // Create a new note
  create: function() {
    if (Note.debug) {
      console.debug("Note.create")
    }

		Note.show()
    
    var insertion_position = Note.getInsertionPosition()
    var top = insertion_position[0]
    var left = insertion_position[1]
    var html = ''
    html += '<div class="note-box unsaved" style="width: 150px; height: 150px; '
    html += 'top: ' + top + 'px; '
    html += 'left: ' + left + 'px;" '
    html += 'id="note-box-' + Note.counter + '">'
    html += '<div class="note-corner" id="note-corner-' + Note.counter + '"></div>'
    html += '</div>'
    html += '<div class="note-body" title="Click to edit" id="note-body-' + Note.counter + '"></div>'
    $("note-container").insert({bottom: html})
    var note = new Note(Note.counter, true, "")
    Note.all.push(note)
    Note.counter -= 1
  },
  
  // Find a suitable position to insert new notes
  getInsertionPosition: function() {
    if (Note.debug) {
      console.debug("Note.getInsertionPosition")
    }
    
    // We want to show the edit box somewhere on the screen, but not outside the image.
    var scroll_x = $("image").cumulativeScrollOffset()[0]
    var scroll_y = $("image").cumulativeScrollOffset()[1]
    var image_left = $("image").positionedOffset()[0]
    var image_top = $("image").positionedOffset()[1]
    var image_right = image_left + $("image").width
    var image_bottom = image_top + $("image").height
    var left = 0
    var top = 0
    
    if (scroll_x > image_left) {
      left = scroll_x
    } else {
      left = image_left
    }
    
    if (scroll_y > image_top) {
      top = scroll_y
    } else {
      top = image_top + 20
    }
    
    if (top > image_bottom) {
      top = image_top + 20
    }
    
    return [top, left]
  }
})


Pool = {
  pools: new Hash(),
  register: function(pool)
  {
    Pool.pools.set(pool.id, pool);
  },

  register_pools: function(pools)
  {
    if(pools != null)
      pools.each(function(pool) { Pool.register(pool); });
  },

  register_pool_posts: function(pool_posts, posts)
  {
    /*
     * pool_post is an array of individual posts in pools.  It contains only data for posts
     * listed in posts.
     *
     * This means that a pool_post not existing in pool_posts only indicates the post is
     * no longer in the pool only if that post is listed in posts.
     *
     * We don't need to clear the pool_posts entry in posts, because the posts registered
     * by this function are always newly registered via Post.register_resp; pool_posts is
     * already empty.
     */
    pool_posts.each(function(pool_post) {
      var post = Post.posts.get(pool_post.post_id);
      if(post)
      {
        if(!post.pool_posts)
          post.pool_posts = new Hash();
        post.pool_posts.set(pool_post.pool_id, pool_post);
      }
    });

  },

  can_edit_pool: function(pool)
  {
    if(!User.is_member_or_higher())
      return false;

   return pool.is_public || pool.user_id == User.get_current_user_id();
  },

  add_post: function(post_id, pool_id) {
    notice("Adding to pool...")

    new Ajax.Request("/pool/add_post.json", {
      parameters: {
        "post_id": post_id,
        "pool_id": pool_id
      },
      onComplete: function(resp) {
        var resp = resp.responseJSON
      
        if (resp.success) {
          notice("Post added to pool")
        } else {
          notice("Error: " + resp.reason)        
        }
      }
    })
  },

  remove_post: function(post_id, pool_id) {
    var complete = function()
    {
      notice("Post removed from pool")
      if($("p" + post_id))
        $("p" + post_id).addClassName("deleted");
      if($("pool" + pool_id))
        $("pool" + pool_id).remove()            
    }

    Post.make_request('/pool/remove_post.json', { "post_id": post_id, "pool_id": pool_id }, complete);
  },

  transfer_post: function(old_post_id, new_post_id, pool_id, sequence)
  {
    Post.update_batch(
      [{ id: old_post_id, tags: "-pool:" + pool_id, old_tags: "" },
       { id: new_post_id, tags: "pool:" + pool_id + ":" + sequence, old_tags: "" }],
      function() {
        notice("Pool post transferred to parent")

	/* We might be on the parent or child, which will do different things to
	 * the pool status display.  Just reload the page. */
	document.location.reload();
      }
    );
  },

  detach_post: function(post_id, pool_id, is_parent)
  {
    Post.update_batch(
      [{ id: post_id, tags: "-pool:" + pool_id, old_tags: "" }],
      function() {
        notice("Post detached")
        if(is_parent) {
          var elem = $("pool-detach-" + pool_id + "-" + post_id);
          if(elem)
            elem.remove()
        } else {
          if($("pool" + pool_id))
            $("pool" + pool_id).remove()
        }
      }
    );
  },

  /* This matches PoolPost.pretty_sequence. */
  post_pretty_sequence: function(sequence)
  {
    if(sequence.match(/^[0-9]+.*/))
      return "#" + sequence;
    else
      return "\"" + sequence + "\"";
  },

  change_sequence: function(post_id, pool_id, old_sequence)
  {
    new_sequence = prompt("Please enter the new page number:", old_sequence);
    if(new_sequence == null)
      return;
    if(new_sequence.indexOf(" ") != -1)
    {
      notice("Invalid page number");
      return;
    }

    Post.update_batch(
      [{ id: post_id, tags: "pool:" + pool_id + ":" + new_sequence, old_tags: "" }],
      function() {
        notice("Post updated")
        var elem = $("pool-seq-" + pool_id);
        if(!Object.isUndefined(elem.innerText))
          elem.innerText = Pool.post_pretty_sequence(new_sequence);
        else
          elem.textContent = Pool.post_pretty_sequence(new_sequence);
      }
    );
  }
}


Post = {
  posts: new Hash(),
  tag_types: new Hash(),
  votes: new Hash(),

  tag_type_names: [
    "general",
    "artist",
    "",
    "copyright",
    "character",
    "circle",
    "faults"
  ],


	find_similar: function() {
		var old_source_name = $("post_source").name
		var old_file_name = $("post_file").name
		var old_target = $("edit-form").target
		var old_action = $("edit-form").action

		$("post_source").name = "url"
		$("post_file").name = "file"
		$("edit-form").target = "_blank"
		$("edit-form").action = "http://danbooru.iqdb.hanyuu.net/"

		$("edit-form").submit()		
		
		$("post_source").name = old_source_name
		$("post_file").name = old_file_name
		$("edit-form").target = old_target
		$("edit-form").action = old_action
	},

  make_request: function(path, params, finished)
  {
    return new Ajax.Request(path, {
      parameters: params,
      
      onFailure: function(req) {
        var resp = req.responseJSON;
	notice("Error: " + resp.reason);
      },

      onSuccess: function(resp) {
        var resp = resp.responseJSON
        Post.register_resp(resp);

        /* Fire posts:update, to allow observers to update their display on change. */
        var post_ids = new Hash();
        for(var i = 0; i < resp.posts.length; ++i)
          post_ids.set(resp.posts[i].id, true);

        document.fire("posts:update", {
          resp: resp,
          post_ids: post_ids
        });

        if(finished)
          finished(resp);
      }
    });
  },

  /* If delete_reason is a string, delete the post with the given reason.  If delete_reason
   * is null, approve the post.  (XXX: rename to Post.moderate) */
  approve: function(post_id, delete_reason, finished) {
    notice("Approving post #" + post_id)
    var params = {}
    params["ids[" + post_id + "]"] = "1"
    params["commit"] = delete_reason? "Delete":"Approve"
    if(delete_reason)
      params["reason"] = delete_reason

    var completion = function()
    {
      notice(delete_reason? "Post deleted":"Post approved");
      if(finished)
        finished(post_id);
      else
      {
        if ($("p" + post_id)) {
          $("p" + post_id).removeClassName("pending")
        }
        if ($("pending-notice")) {
          $("pending-notice").hide()
        }
      }
    }

    return Post.make_request("/post/moderate.json", params, completion);
  },

  undelete: function(post_id, finished)
  {
    return Post.make_request("/post/undelete.json", {id: post_id}, finished);
  },

  applied_list: [],
  reset_tag_script_applied: function() {
    for(var i=0; i < Post.applied_list.length; ++i)
      Post.applied_list[i].removeClassName("tag-script-applied");

    Post.applied_list = []
  },

  /*
   * posts is an array of the form:
   *
   * [{ id: 123, tags: "tags", old_tags: "tags2" },
   *  { id: 124, tags: "tags3", old_tags: "tags4" }]
   *
   * and we pass it as a query string that results in:
   *
   * [{ :id="123", :tags = "tags", :old_tags => "tags2" },
   *  { :id="124", :tags = "tags3", :old_tags => "tags4" }]
   *
   * Prototype won't generate a query string to do this.  We also need to hack Prototype
   * to keep it from messing around with the parameter order (bug).
   *
   * One significant difference between using this and update() is that this will
   * receive secondary updates: if you change a parent with this function, the parent
   * will have its styles (border color) updated.  update() only receives the results
   * of the post that actually changed, and won't update other affected posts.
   */
  update_batch: function(posts, finished) {
    var original_count = posts.length;

    if(TagCompletion)
    {
      /* Tell TagCompletion about recently used tags. */
      posts.each(function(post) {
        if(post.tags == null)
          return;

        TagCompletion.add_recent_tags_from_update(post.tags, post.old_tags);
      });
    }

    /* posts is a hash of id: { post }.  Convert this to a Rails-format object array. */
    var params_array = [];                  
    posts.each(function(post) {
      $H(post).each(function(pair2) {
        var s = "post[][" + pair2.key + "]=" + window.encodeURIComponent(pair2.value);
        params_array.push(s);
      });
    });

    var complete = function(resp)
    {
      resp.posts.each(function(post) {
        Post.update_styles(post);

        var element = $$("#p" + post.id + " > .directlink")
        if (element.length > 0) {
          element[0].addClassName("tag-script-applied")
          Post.applied_list.push(element[0])
        }
      });

      notice((original_count == 1? "Post": "Posts") + " updated");

      if(finished)
        finished(resp.posts);
    }

    var params = params_array.join("&");
    Post.make_request("/post/update_batch.json", params, complete);
  },

  update_styles: function(post)
  {
    var e = $("p" + post.id);
    if(!e) return;
    if(post["has_children"])
      e.addClassName("has-children");
    else
      e.removeClassName("has-children");

    if(post["parent_id"])
      e.addClassName("has-parent");
    else
      e.removeClassName("has-parent");
  },

  /* Deprecated; use Post.update_batch instead. */
  update: function(post_id, params, finished) {
    notice('Updating post #' + post_id)
    params["id"] = post_id

    new Ajax.Request('/post/update.json', {
      parameters: params,

      onComplete: function(resp) {
        var resp = resp.responseJSON

        if (resp.success) {
          notice('Post updated')

          // Update the stored post.
          Post.register(resp.post)
          Post.register_tags(resp.tags);

          Post.update_styles(resp.post);

          var element = element = $$("#p" + post_id + " > .directlink")
          if (element.length > 0) {
            element[0].addClassName("tag-script-applied")
            Post.applied_list.push(element[0])
          }

          if(finished)
            finished(resp.post);
        } else {
          notice('Error: ' + resp.reason)
        }
      }
    })
  },

  activate_posts: function(post_ids, finished)
  {
    notice("Activating " + post_ids.length + (post_ids.length == 1? " post":" posts"));
    var params = {};
    params["post_ids[]"] = post_ids

    new Ajax.Request('/post/activate.json', {
      parameters: params,

      onComplete: function(resp) {
        var resp = resp.responseJSON

        if (resp.success) {
          if(finished)
            finished(resp);
        } else {
          notice('Error: ' + resp.reason)
        }
      }
    })
  },

  activate_all_posts: function()
  {
    var post_ids = [];
    Post.posts.each(function(pair) {
      /* Only activate posts that are actually displayed; we may have others registered. */
      if($("p" + pair.key))
        post_ids.push(pair.key);
    });
    Post.activate_posts(post_ids, function(resp) {
      if(resp.count == 0)
        notice("No posts were activated.");
      else
        notice(resp.count + (resp.count == 1? " post":" posts") + " activated");
    });
  },

  /* Activating a single post uses post/update, which returns the finished post, so we can
   * check if the change was made.  activate_posts uses post/activate, which works in bulk
   * and doesn't return errors for individual posts. */
  activate_post: function(post_id)
  {
     Post.update_batch([{ id: post_id, is_held: false }], function()
     {
       var post = Post.posts.get(post_id);
       if(post.is_held)
         notice("Couldn't activate post");
       else
         $("held-notice").remove();
     });
  },


  init_add_to_favs: function(post_id, add_to_favs, remove_from_favs) {
    var update_add_to_favs = function(e)
    {
      if(e != null && e.memo.post_ids.get(post_id) == null)
        return;
      var vote = Post.votes.get(post_id) || 0;
      add_to_favs.show(vote < 3);
      remove_from_favs.show(vote >= 3);
    }

    update_add_to_favs();
    document.on("posts:update", update_add_to_favs);
  },

  vote: function(post_id, score) {
    if(score > 3)
      return;
    
    notice("Voting...")
    Post.make_request("/post/vote.json", { id: post_id, score: score }, function(resp) { notice("Vote saved"); });
  },

  flag: function(id, finished) {
    var reason = prompt("Why should this post be flagged for deletion?", "")
    if (!reason)
      return false;
  
    var complete = function()
    {
      notice("Post was flagged for deletion");
      if(finished)
        finished(id);
      else
      {
        var e = $("p" + id);
        if(e)
          e.addClassName("flagged");
      }
    }

    return Post.make_request("/post/flag.json", { "id": id, "reason": reason }, complete);
  },

  unflag: function(id, finished) {
    var complete = function()
    {
      notice("Post was approved");
      if(finished)
        finished(id);
      else
      {
        var e = $("p" + id);
        if(e)
          e.removeClassName("flagged");
      }
    }

    return Post.make_request("/post/flag.json", { id: id, unflag: 1 }, complete);
  },

  observe_text_area: function(field_id) {
    $(field_id).observe("keydown", function(e) {
      if (e.keyCode == Event.KEY_RETURN) {
        e.stop();
        this.up("form").simulate_submit();
      }
    })
  },

  /* 
   * Group tags by type. 
   *
   * Post.get_post_tags_by_type(post)
   * -> {general: ["tagme"], faults: ["fixme", "crease"]}
   */
  get_post_tags_by_type: function(post)
  {
    var results = new Hash;

    post.tags.each(function(tag)
    {
      var tag_type = Post.tag_types.get(tag);

      /* We can end up not knowing a tag's type due to tag script editing giving us
       * tags we weren't told the type of. */
      if(!tag_type)
        tag_type = "general";
      var list = results.get(tag_type);
      if(!list)
      {
        list = [];
        results.set(tag_type, list);
      }
      list.push(tag);
    });

    return results;
  },

  /* 
   * Get post tags with their types.
   *
   * Post.get_post_tags_with_type(post)
   * -> [["tagme", "general"], ["fixme", "faults"], ["crease", "faults"]]
   *
   * The results will be sorted by type.
   */
  get_post_tags_with_type: function(post)
  {
    var tag_types = Post.get_post_tags_by_type(post);
    var types = tag_types.keys();

    var type_order = ["artist", "circle", "copyright", "character", "faults", "general"];
    types = types.sort(function(a, b) {
      var a_idx = type_order.indexOf(a);
      if(a_idx == -1) a_idx = 999;
      var b_idx = type_order.indexOf(b);
      if(b_idx == -1) b_idx = 999;
      return a_idx - b_idx;
    });

    var results = new Array;
    types.each(function(type) {
      var tags = tag_types.get(type);
      tags.each(function(tag) {
        results.push([tag, type]);
      });
    });
    return results;
  },

  /* Register all data from a generic post response. */
  register_resp: function(resp) {
    if(resp.posts)
      Post.register_posts(resp.posts);
    if(resp.tags)
      Post.register_tags(resp.tags);
    if(resp.votes)
      Post.register_votes(resp.votes);
    if(resp.pools)
      Pool.register_pools(resp.pools);
    if(resp.pool_posts)
      Pool.register_pool_posts(resp.pool_posts, resp.posts);
  },

  register: function(post) {
    post.tags = post.tags.match(/\S+/g) || []
    post.match_tags = post.tags.clone()
    post.match_tags.push("rating:" + post.rating.charAt(0))
    post.match_tags.push("status:" + post.status)

    this.posts.set(post.id, post)
  },

  register_posts: function(posts) {
    posts.each(function(post) { Post.register(post); });
  },

  unregister_all: function() {
    this.posts = new Hash();
  },

  /* Post.register_tags({tagme: "general"}); */
  register_tags: function(tags, no_send_to_completion) {
    this.tag_types.update(tags);

    /* If no_send_to_completion is true, this data is coming from completion, so there's
     * no need to send it back. */
    if(TagCompletion && !no_send_to_completion)
      TagCompletion.update_tag_types();
  },

  /* Post.register_votes({12345: 1}) */
  register_votes: function(votes) {
    this.votes.update(votes);
  },

  blacklists: [],

  is_blacklisted: function(post_id) {
    var post = Post.posts.get(post_id)
    var has_tag = function(tag) { return post.match_tags.indexOf(tag) != -1; };

    /* This is done manually, since this needs to be fast and Prototype's functions are
     * too slow. */
    var blacklist_applies = function(b)
    {
      var require = b.require;
      var require_len = require.length;
      for(var j = 0; j < require_len; ++j)
      {
        if(!has_tag(require[j]))
          return false;
      }

      var exclude = b.exclude;
      var exclude_len = exclude.length;
      for(var j = 0; j < exclude_len; ++j)
      {
        if(has_tag(exclude[j]))
          return false;
      }

      return true;
    }

    var blacklists = Post.blacklists;
    var len = blacklists.length;
    for(var i = 0; i < len; ++i)
    {
      var b = blacklists[i];
      if(blacklist_applies(b))
        return true;
    }
    return false;
  },

  apply_blacklists: function() {	
    Post.blacklists.each(function(b) { b.hits = 0 })

    var count = 0
    Post.posts.each(function(pair) {
      var thumb = $("p" + pair.key)
      if (!thumb) return

      var post = pair.value

      var has_tag = post.match_tags.member.bind(post.match_tags)
      post.blacklisted = []
      if(post.id != Post.blacklist_options.exclude)
      {
        Post.blacklists.each(function(b) {
          if (b.require.all(has_tag) && !b.exclude.any(has_tag)) {
            b.hits++
            if (!Post.disabled_blacklists[b.tags]) post.blacklisted.push(b)
          }
        })
      }
      var bld = post.blacklisted.length > 0

      /* The class .javascript-hide hides elements only if JavaScript is enabled, and is
       * applied to all posts by default; we remove the class to show posts.  This prevents
       * posts from being shown briefly during page load before this script is executed,
       * but also doesn't break the page if JavaScript is disabled. */
      count += bld
      if (Post.blacklist_options.replace)
      {
        if(bld)
        {
          thumb.src = "about:blank";

          /* Trying to work around Firefox displaying the old thumb.src briefly before loading
           * the blacklisted thumbnail, even though they're applied at the same time: */
          var f = function(event)
          {
            var img = event.target;
            img.stopObserving("load");
            img.stopObserving("error");
            img.src = "/blacklisted-preview.png";
            img.removeClassName("javascript-hide");
          }
          thumb.observe("load", f)
          thumb.observe("error", f)
        }
        else
        {
          thumb.src = post.preview_url;
          thumb.removeClassName("javascript-hide");
        }
      }
      else
      {
        if(bld)
          thumb.addClassName("javascript-hide");
        else
          thumb.removeClassName("javascript-hide");
      }
    })

    if (Post.countText)
      Post.countText.update(count);

    var notice = $("blacklisted-notice");
    if(notice)
      notice.show(count > 0);

    return count
  },

  // When blacklists are added dynamically and saved, add them here so we don't have to try
  // to edit the cookie in-place.
  current_blacklists: null,
  hide_inactive_blacklists: true,
  disabled_blacklists: {},

  blacklists_update_disabled: function() {
    Post.blacklists.each(function(b) {
      if(!b.a)
        return;
      if(Post.disabled_blacklists[b.tags] || b.hits == 0)
        b.a.addClassName("blacklisted-tags-disabled");
      else
        b.a.removeClassName("blacklisted-tags-disabled");
    });
  },

  // XXX: we lose exclude and replace when we're re-called
  init_blacklisted: function(options) {
    Post.blacklist_options = Object.extend({
      replace: false,
      exclude: null
    }, options);  
    var bl_entries;
    if(Post.current_blacklists)
      bl_entries = Post.current_blacklists;
    else
    {
      bl_entries = Cookie.raw_get("blacklisted_tags").split(/\&/);
      for(var i = 0; i < bl_entries.length; ++i)
        bl_entries[i] = Cookie.unescape(bl_entries[i]);
    }

    Post.blacklists = [];
    bl_entries.each(function(val) {
        var s = val.replace(/(rating:[qes])\w+/, "$1")
        var tags = s.match(/\S+/g)
        if (!tags) return
        var b = { tags: tags, original_tag_string: val, require: [], exclude: [], hits: 0 }
        tags.each(function(tag) {
          if (tag.charAt(0) == '-') b.exclude.push(tag.slice(1))
          else b.require.push(tag)
        })
        Post.blacklists.push(b)
    })
  
    Post.countText = $("blacklist-count")
    if(Post.countText)
      Post.countText.update("");

    Post.apply_blacklists();

    var sidebar = $("blacklisted-sidebar")
    if (sidebar)
      sidebar.show()

    var list = $("blacklisted-list")
    if(list)
    {
      while(list.firstChild)
        list.removeChild(list.firstChild);

      Post.blacklists.sort(function(a, b) {
        if(a.hits == 0 && b.hits > 0) return 1;
        if(a.hits > 0 && b.hits == 0) return -1;
        return a.tags.join(" ").localeCompare(b.tags.join(" "));
      });

      inactive_blacklists_hidden = 0
      Post.blacklists.each(function(b) {
        if (Post.hide_inactive_blacklists && !b.hits)
        {
          ++inactive_blacklists_hidden;
          return;
        }


        var li = list.appendChild(document.createElement("li"))
        li.className = "blacklisted-tags"
        li.style.position = "relative";

        var del = li.appendChild($(document.createElement("a")));
        del.style.position = "absolute";
        del.style.left = "-0.75em";
        del.href = "#";
        del.update("⊘");

        del.observe("click", function(event) {
          /* We need to call run_login_onclick ourself, since this form isn't created with the form helpers. */
          if(!User.run_login_onclick(event)) return false;

          event.stop();

          var tag = b.original_tag_string;
          User.modify_blacklist([], [tag], function(resp) {
            notice("Unblacklisted \"" + tag + "\"");

            Post.current_blacklists = resp.result;
            Post.init_blacklisted();
          });
        });

        li.appendChild(document.createTextNode("» "));

        var a = li.appendChild(document.createElement("a"))
        b.a = a;
        a.href = "#"
        a.className = "no-focus-outline"

        if(!b.hits) {
          a.addClassName("blacklisted-tags-disabled");
        } else {
          $(a).observe("click", function(event) {
            Post.disabled_blacklists[b.tags] = !Post.disabled_blacklists[b.tags]

            Post.apply_blacklists()
            Post.blacklists_update_disabled();
            event.stop()
          });
        }

        var tags = a.appendChild(document.createTextNode(b.tags.join(" ")));
        li.appendChild(document.createTextNode(" "));
        var span = li.appendChild(document.createElement("span"))
        span.className = "post-count"
        if(b.hits > 0)
          span.appendChild(document.createTextNode("(" + b.hits + ")"));
      })

      /* Add the "Show all blacklists" button.  If Post.hide_inactive_blacklists is false, then
       * we've already clicked it and hidden it, so don't recreate it. */
      if(Post.hide_inactive_blacklists && inactive_blacklists_hidden > 0)
      {
        var li = list.appendChild(document.createElement("li"))
        li.className = "no-focus-outline"
        li.id = "blacklisted-tag-show-all"

        var a = li.appendChild(document.createElement("a"))
        a.href = "#"
        a.className = "no-focus-outline"

        $(a).observe("click", function(event) {
          event.stop();
          $("blacklisted-tag-show-all").hide();
          Post.hide_inactive_blacklists = false;
          Post.init_blacklisted();
        });

        var tags = a.appendChild(document.createTextNode("» Show all blacklists"));
        li.appendChild(document.createTextNode(" "));
      }
    }

    Post.blacklists_update_disabled();
  },

  blacklist_add_commit: function()
  {
    var tag = $("add-blacklist").value;
    if(tag == "")
      return;

    $("add-blacklist").value = "";
    User.modify_blacklist(tag, [], function(resp) {
      notice("Blacklisted \"" + tag + "\"");

      Post.current_blacklists = resp.result;
      Post.init_blacklisted();
    });
  },

  last_click_id: null,
  check_avatar_blacklist: function(post_id, id)
  {
    if(id && id == this.last_click_id)
      return true;
    this.last_click_id = id;

    if(!Post.is_blacklisted(post_id))
      return true;

    notice("This post matches one of your blacklists.  Click again to open.");
    return false;
  },

  resize_image: function() {
    var img = $("image");

    if(img.original_width == null)
    {
      img.original_width = img.width;
      img.original_height = img.height;
    }

    var ratio = 1;
    if ((img.scale_factor == 1) || (img.scale_factor == null)) {
      /* Use clientWidth for sizing the width, and the window height for the height.
       * This prevents needing to scroll horizontally to center the image. */
      var client_width = $("right-col").clientWidth - 15;
      var client_height = window.innerHeight - 15;
      ratio = Math.min(ratio, client_width / img.original_width);
      ratio = Math.min(ratio, client_height / img.original_height);
    }
    img.width = img.original_width * ratio;
    img.height = img.original_height * ratio;
    img.scale_factor = ratio;
  
    if (window.Note) {
      for (var i=0; i<window.Note.all.length; ++i) {
        window.Note.all[i].adjustScale()
      }
    }
  },
  
  get_scroll_offset_to_center: function(element)
  {
    var window_size = document.viewport.getDimensions();
    var offset = element.cumulativeOffset();
    var left_spacing = (window_size.width - element.offsetWidth) / 2;
    var top_spacing = (window_size.height - element.offsetHeight) / 2;
    var scroll_x = offset.left - left_spacing;
    var scroll_y = offset.top - top_spacing;
    return [scroll_x, scroll_y];
  },
  center_image: function(img)
  {
    /* Make sure we have enough space to scroll far enough to center the image.  Set a
     * minimum size on the body to give us more space on the right and bottom, and add
     * a padding to the image to give more space on the top and left. */
    if(!img)
      img = $("image");
    if(!img)
      return;

    /* Any existing padding (possibly from a previous call to this function) will be
     * included in cumulativeOffset and throw things off, so clear it. */
    img.setStyle({paddingLeft: 0, paddingTop: 0});

    var target_offset = Post.get_scroll_offset_to_center(img);
    var padding_left = -target_offset[0];
    if(padding_left < 0) padding_left = 0;
    img.setStyle({paddingLeft: padding_left + "px"});

    var padding_top = -target_offset[1];
    if(padding_top < 0) padding_top = 0;
    img.setStyle({paddingTop: padding_top + "px"});

    var window_size = document.viewport.getDimensions();
    var required_width = target_offset[0] + window_size.width;
    var required_height = target_offset[1] + window_size.height;
    $(document.body).setStyle({minWidth: required_width + "px", minHeight: required_height + "px"});

    /* Resizing the body may shift the image to the right, since it's centered in the content.
     * Recalculate offsets with the new cumulativeOffset. */
    var target_offset = Post.get_scroll_offset_to_center(img);
    window.scroll(target_offset[0], target_offset[1]);
  },

  scale_and_fit_image: function(img)
  {
    if(!img)
      img = $("image");
    if(!img)
      return;

    if(img.original_width == null)
    {
      img.original_width = img.width;
      img.original_height = img.height;
    }
    var window_size = document.viewport.getDimensions();
    var client_width = window_size.width;
    var client_height = window_size.height;

    /* Zoom the image to fit the viewport. */
    var ratio = client_width / img.original_width;
    if (img.original_height * ratio > client_height)
      ratio = client_height / img.original_height;
    if(ratio < 1)
    {
      img.width = img.original_width * ratio;
      img.height = img.original_height * ratio;
    }

    this.center_image(img);

    Post.adjust_notes();
  },

  adjust_notes: function() {
    if (!window.Note)
      return;
    for (var i=0; i<window.Note.all.length; ++i) {
      window.Note.all[i].adjustScale()
    }
  },


  highres: function() {
    var img = $("image");
    if(img.already_resized)
      return;
    img.already_resized = true;
    
    // un-resize
    if ((img.scale_factor != null) && (img.scale_factor != 1)) {
      Post.resize_image();
    }

    var f = function() {
      img.stopObserving("load")
      img.stopObserving("error")
      img.original_height = null;
      img.original_width = null;
      var highres = $("highres-show");
      img.height = highres.getAttribute("link_height");
      img.width = highres.getAttribute("link_width");
      img.src = highres.href;

      if (window.Note) {
        window.Note.all.invoke("adjustScale")
      }
    }
    
    img.observe("load", f)
    img.observe("error", f)

    // Clear the image before loading the new one, so it doesn't show the old image
    // at the new resolution while the new one loads.  Hide it, so we don't flicker
    // a placeholder frame.
    if($('resized_notice'))
      $('resized_notice').hide();
    img.height = img.width = 0
    img.src = "about:blank"
  },

  set_same_user: function(creator_id)
  {
    var old = $("creator-id-css");
    if(old)
      old.parentNode.removeChild(old);

    var css = ".creator-id-"+ creator_id + " .directlink { background-color: #300 !important; }";
    var style = document.createElement("style");
    style.id = "creator-id-css";
    style.type = "text/css";
    if(style.styleSheet) // IE
      style.styleSheet.cssText = css;
    else
      style.appendChild(document.createTextNode(css));
    document.getElementsByTagName("head")[0].appendChild(style);
  },

  init_post_list: function()
  {
    Post.posts.each(function(p)
    {
      var post_id = p[0]
      var post = p[1]
      var directlink = $("p" + post_id)
      if (!directlink)
        return;
      directlink = directlink.down(".directlink")
      if (!directlink)
        return;
      directlink.observe('mouseover', function(event) { Post.set_same_user(post.creator_id); return false; }, true);
      directlink.observe('mouseout', function(event) { Post.set_same_user(null); return false; }, true);
    });
  },

  init_hover_thumb: function(hover, post_id, thumb, container)
  {
    /* Hover thumbs trigger rendering bugs in IE7. */
    if(Prototype.Browser.IE)
      return;
    hover.observe("mouseover", function(e) { Post.hover_thumb_mouse_over(post_id, hover, thumb, container); });
    hover.observe("mouseout", function(e) { if(e.relatedTarget == thumb) return; Post.hover_thumb_mouse_out(thumb); });
    if(!thumb.hover_init) {
      thumb.hover_init = true;
      thumb.observe("mouseout", function(e) { Post.hover_thumb_mouse_out(thumb); });
    }

  },

  hover_thumb_mouse_over: function(post_id, AlignItem, image, container)
  {
    var post = Post.posts.get(post_id);
    image.hide();

    var offset = AlignItem.cumulativeOffset();
    image.style.width = "auto";
    image.style.height = "auto";
    if(Post.is_blacklisted(post_id))
    {
      image.src = "/preview/blacklisted.png";
    }
    else
    {
      image.src = post.preview_url;
      if(post.status != "deleted")
      {
        image.style.width = post.actual_preview_width + "px";
        image.style.height = post.actual_preview_height + "px";
      }
    }

    var container_top = container.cumulativeOffset().top;
    var container_bottom = container_top + container.getHeight() - 1;

    /* Normally, align to the item we're hovering over.  If the image overflows over
     * the bottom edge of the container, shift it upwards to stay in the container,
     * unless the container's too small and that would put it over the top. */
    var y = offset.top-2; /* -2 for top 2px border */
    if(y + image.getHeight() > container_bottom)
    {
      var bottom_aligned_y = container_bottom - image.getHeight() - 4; /* 4 for top 2px and bottom 2px borders */
      if(bottom_aligned_y >= container_top)
        y = bottom_aligned_y;
    }

    image.style.top = y + "px";
    image.show();
  },

  hover_thumb_mouse_out: function(image)
  {
    image.hide();
  },

  acknowledge_new_deleted_posts: function(post_id) {
    new Ajax.Request("/post/acknowledge_new_deleted_posts.json", {
      onComplete: function(resp) {
        var resp = resp.responseJSON
        
        if (resp.success)
	{
          if ($("posts-deleted-notice"))
            $("posts-deleted-notice").hide()
        } else {
          notice("Error: " + resp.reason)
        }
      }
    })
  },

  hover_info_pin: function(post_id)
  {
    var post = null;
    if(post_id != null)
      post = Post.posts.get(post_id);    
    Post.hover_info_pinned_post = post;
    Post.hover_info_update();
  },

  hover_info_mouseover: function(post_id)
  {
    var post = Post.posts.get(post_id);    
    if(Post.hover_info_hovered_post == post)
      return;
    Post.hover_info_hovered_post = post;
    Post.hover_info_update();
  },

  hover_info_mouseout: function()
  {
    if(Post.hover_info_hovered_post == null)
      return;
    Post.hover_info_hovered_post = null;
    Post.hover_info_update();
  },

  hover_info_hovered_post: null,
  hover_info_displayed_post: null,
  hover_info_shift_held: false,
  hover_info_pinned_post: null, /* pinned by something like the edit menu; shift state and mouseover is ignored */

  hover_info_update: function()
  {
    var post = Post.hover_info_pinned_post;
    if(!post)
    {
      post = Post.hover_info_hovered_post;
      if(!Post.hover_info_shift_held)
        post = null;
    }

    if(Post.hover_info_displayed_post == post)
      return;
    Post.hover_info_displayed_post = post;

    var hover = $("index-hover-info");
    var overlay = $("index-hover-overlay");
    if(!post)
    {
      hover.hide();
      overlay.hide();
      overlay.down("IMG").src = "about:blank";
      return;
    }
    hover.down("#hover-dimensions").innerHTML = post.width + "x" + post.height;
    hover.select("#hover-tags SPAN A").each(function(elem) {
      elem.innerHTML = "";
    });
    var tags_by_type = Post.get_post_tags_by_type(post);
    tags_by_type.each(function(key) {
      var elem = $("hover-tag-" + key[0]);
      var list = []
      key[1].each(function(tag) { list.push(tag); });
      elem.innerHTML = list.join(" ");
    });
    if(post.rating=="s")
      hover.down("#hover-rating").innerHTML = "s";
    else if(post.rating=="q")
      hover.down("#hover-rating").innerHTML = "q";
    else if(post.rating=="e")
      hover.down("#hover-rating").innerHTML = "e";
    hover.down("#hover-post-id").innerHTML = post.id;
    hover.down("#hover-score").innerHTML = post.score;
    if(post.is_shown_in_index)
      hover.down("#hover-not-shown").hide();
    else
      hover.down("#hover-not-shown").show();
    hover.down("#hover-is-parent").show(post.has_children);
    hover.down("#hover-is-child").show(post.parent_id != null);
    hover.down("#hover-is-pending").show(post.status == "pending");
    hover.down("#hover-is-flagged").show(post.status == "flagged");
    var set_text_content = function(element, text)
    {
      (element.innerText || element).textContent = text;
    }

    if(post.status == "flagged")
    {
      hover.down("#hover-flagged-reason").setTextContent(post.flag_detail.reason);
      hover.down("#hover-flagged-by").setTextContent(post.flag_detail.flagged_by);
    }

    hover.down("#hover-file-size").innerHTML = number_to_human_size(post.file_size);
    hover.down("#hover-author").innerHTML = post.author;
    hover.show();

    /* Reset the box to 0x0 before polling the size, so it expands to its maximum size,
     * and read the size. */
    hover.style.left = "0px";
    hover.style.top = "0px";
    var hover_width = hover.scrollWidth;
    var hover_height = hover.scrollHeight;

    var hover_thumb = $("p" + post.id).down("IMG");
    var thumb_offset = hover_thumb.cumulativeOffset();
    var thumb_center_x = thumb_offset[0] + hover_thumb.scrollWidth/2;
    var thumb_top_y = thumb_offset[1];
    var x = thumb_center_x - hover_width/2;
    var y = thumb_top_y - hover_height;

    /* Clamp the X coordinate so the box doesn't fall off the side of the screen.  Don't
     * clamp Y. */
    var client_width = document.viewport.getDimensions()["width"];
    if(x < 0) x = 0;
    if(x + hover_width > client_width) x = client_width - hover_width;
    hover.style.left = x + "px";
    hover.style.top = y + "px";

    overlay.down("A").href = (User.get_use_browser()?  "/post/browse#":"/post/show/") + post.id;
    overlay.down("IMG").src = post.preview_url;
    
    /* This doesn't always align properly in Firefox if full-page zooming is being
     * used. */
    var x = thumb_center_x - post.actual_preview_width/2;
    var y = thumb_offset[1];
    overlay.style.left = x + "px";
    overlay.style.top = y + "px";
    overlay.show();
  },

  hover_info_shift_down: function()
  {
    if(Post.hover_info_shift_held)
      return;
    Post.hover_info_shift_held = true;
    Post.hover_info_update();
  },

  hover_info_shift_up: function()
  {
    if(!Post.hover_info_shift_held)
      return;
    Post.hover_info_shift_held = false;
    Post.hover_info_update();
  },

  hover_info_init: function()
  {
    document.observe("keydown", function(e) {
      if(e.keyCode != 16) /* shift */
        return;
      Post.hover_info_shift_down();
    });

    document.observe("keyup", function(e) {
      if(e.keyCode != 16) /* shift */
        return;
      Post.hover_info_shift_up();
    });

    document.observe("blur", function(e) { Post.hover_info_shift_up(); });

    var overlay = $("index-hover-overlay");
    Post.posts.each(function(p) {
      var post_id = p[0]
      var post = p[1]

      var span = $("p" + post.id);
      if(span == null)
        return;

      span.down("A").observe("mouseover", function(e) { Post.hover_info_mouseover(post_id); });
      span.down("A").observe("mouseout", function(e) { if(e.relatedTarget && e.relatedTarget.isParentNode(overlay)) return; Post.hover_info_mouseout(); });
    });

    overlay.observe("mouseout", function(e) { Post.hover_info_mouseout(); });
  },

  highlight_posts_with_tag: function(tag)
  {
    Post.posts.each(function(p) {
      var post_id = p[0]
      var post = p[1]
      var thumb = $("p" + post.id);
      if(!thumb)
        return;

      if(tag && post.tags.indexOf(tag) != -1)
      {
        thumb.addClassName("highlighted-post");
      } else {
        thumb.removeClassName("highlighted-post");
      }
    });
  },

  reparent_post: function(post_id, old_parent_id, has_grandparent, finished)
  {
    /* If the parent has a parent, this is too complicated to handle automatically. */
    if(has_grandparent)
    {
      alert("The parent post has a parent, so this post can't be automatically reparented.");
      return;
    }

    /*
     * Request a list of child posts.
     * The parent post itself will be returned by parent:.  This is expected; it'll cause us
     * to parent the post to itself, which unparents it from the old parent.
     */
    var change_requests = [];
    new Ajax.Request("/post/index.json", {
      parameters: { tags: "parent:" + old_parent_id },
      
      onComplete: function(resp) {
        var resp = resp.responseJSON
	for(var i = 0; i < resp.length; ++i)
	{
          var post = resp[i];
          if(post.id == old_parent_id && post.parent_id != null)
          {
            alert("The parent post has a parent, so this post can't be automatically reparented.");
            return;
          }
	  change_requests.push({ id: resp[i].id, tags: "parent:" + post_id, old_tags: "" });
        }

	/* We have the list of changes to make in change_requests.  Send a batch
	 * request. */
        if(finished == null)
          finished = function() { document.location.reload() };
	Post.update_batch(change_requests, finished);
      }
    });
  },
  get_url_for_post_in_pool: function(post_id, pool_id)
  {
    return "/post/show/" + post_id + "?pool_id=" + pool_id;
  },
  jump_to_post_in_pool: function(post_id, pool_id)
  {
    if(post_id == null)
    {
      notice("No more posts in this pool");
      return;
    }
    window.location.href = Post.get_url_for_post_in_pool(post_id, pool_id);
  },

  /*
   * If the user has global browser links enabled, apply them.  This changes all links
   * from /post/show/123 to /post/browse#123, and /pool/show/123 to /post/browse#/pool:123.
   * 
   * We do this in JS, so it applies without affecting memcached pages, and applies to
   * things like preformatted, translated DText blocks.
   *
   * This is only done if the user's "Use post browser" (User.use_browser) setting is enabled.
   */
  InitBrowserLinks: function()
  {
    if(!User.get_use_browser())
      return;

    /*
     * Break out the controller, action, ID and anchor:
     * http://url.com/post/show/123#anchor
     */
    var parse_url = function(href)
    {
      var match = href.match(/^(http:\/\/[^\/]+)\/([a-z]+)\/([a-z]+)\/([0-9]+)([^#]*)(#.*)?$/);
      if(!match)
        return null;

      return {
        controller: match[2],
        action: match[3],
        id: match[4],
        hash: match[6]
      };
    }

    /*
     * Parse an index search URL and return the tags.  Only accept URLs with no other parameters;
     * this shouldn't match the paginator in post/index.
     *
     * http://url.com/post?tags=tagme
     */
    var parse_index_url = function(href)
    {
      var match = href.match(/^(http:\/\/[^\/]+)\/post(\/index)?\?tags=([^&]*)$/);
      if(!match)
        return null;
      return match[3];
    }

    /* If the current page is /pool/show, make post links include both the post ID and
     * the pool ID, eg. "#12345/pool:123". */
    var current = parse_url(document.location.href);
    var current_pool_id = null;
    if(current && current.controller == "pool" && current.action == "show")
      current_pool_id = current.id;

    $$("A").each(function(a) {
      if(a.hasClassName("no-browser-link") || a.up(".no-browser-link"))
        return;

      var tags = parse_index_url(a.href);
      if(tags != null)
      {
        a.href = "/post/browse#/" + tags;
        return;
      }
      var target = parse_url(a.href);
      if(!target)
        return;

      /* If the URL has a hash, then it's something like a post comment link, so leave it
       * alone. */
      if(target.hash)
        return;

      if(target.controller == "post" && target.action == "show")
      {
        var url = "/post/browse#" + target.id;
        if(current_pool_id != null)
          url += "/pool:" + current_pool_id;
        a.browse_href = url;
        a.orig_href = a.href;
      }
      else if(target.controller == "pool" && target.action == "show")
      {
        a.browse_href = "/post/browse#/pool:" + target.id;
        a.orig_href = a.href;
      }

      if(a.browse_href)
        a.href = a.browse_href;
    });
  },

  /* Handle the sample URL cache.  This allows pages that statically know sample URLs for
   * files (post/index) to communicate that to dynamic pages that normally get it from
   * XHR (post/browse). */
  cached_sample_urls: null,            

  /* Return an object containing cached sample URLs, eg. {"12345": "http://example.com/image.jpg"}.
   * If the browser lacks support for this, return null.  If the stored data is invalid or doesn't
   * yet exist, return {}. */
  get_cached_sample_urls: function()
  {
    if(LocalStorageDisabled())
      return null;

    /* If the data format is out of date, clear it. */
    if(localStorage.sample_url_format != 2)
      Post.clear_sample_url_cache();

    if(Post.cached_sample_urls != null)
      return Post.cached_sample_urls;

    try {
      var sample_urls = JSON.parse(window.localStorage.sample_urls);
    } catch(SyntaxError) {
      return {};
    }

    if(sample_urls == null)
      return {};

    Post.cached_sample_urls = sample_urls;
    return sample_urls;
  },

  clear_sample_url_cache: function()
  {
    if("sample_urls" in localStorage)
      delete window.localStorage.sample_urls;
    if("sample_url_fifo" in localStorage)
      delete window.localStorage.sample_url_fifo;
    localStorage.sample_url_format = 2;
  },

  /* Save all loaded posts to the sample URL cache, and expire old data. */
  cache_sample_urls: function()
  {
    var sample_urls = Post.get_cached_sample_urls();
    if(sample_urls == null)
      return;

    /* Track post URLs in the order we see them, and push old data out. */
    var fifo = window.localStorage.sample_url_fifo || null;
    fifo = fifo? fifo.split(","): [];

    Post.posts.each(function(id_and_post) {
      var post = id_and_post[1];
      if(post.sample_url)
        sample_urls[post.id] = post.sample_url;
      fifo.push(post.id);
    });

    /* Erase all but the most recent 1000 items. */
    fifo = fifo.splice(-1000);

    /* Make a set of the FIFO, so we can do lookups quickly. */
    var fifo_set = {}
    fifo.each(function(post_id) { fifo_set[post_id] = true; });

    /* Make a list of items no longer in the FIFO to be deleted. */
    var post_ids_to_expire = [];
    for(post_id in sample_urls)
    {
      if(!(post_id in fifo_set))
        post_ids_to_expire.push(post_id);
    }

    /* Erase items no longer in the FIFO. */
    post_ids_to_expire.each(function(post_id) { delete sample_urls[post_id]; });

    /* Save the cached items and FIFO back to localStorage. */
    Post.cached_sample_urls = sample_urls;
    try {
      window.localStorage.sample_urls = JSON.stringify(sample_urls);
      window.localStorage.sample_url_fifo = fifo.join(",");
    } catch(e) {
      /* If this fails for some reason, clear the data. */
      Post.clear_sample_url_cache();
      throw(e);
    }
  },

  prompt_to_delete: function(post_id, completed)
  {
    if(completed == null)
      completed = function() { window.location.reload(); };

    var flag_detail = Post.posts.get(post_id).flag_detail
    var default_reason = flag_detail? flag_detail.reason:"";
    var reason = prompt('Reason:', default_reason);
    if(!reason)
      return false;

    Post.approve(post_id, reason, completed);
    return true;
  }
}


var create_drag_box = function(div)
{
  var create_handle = function(cursor, style)
  {
    var handle = $(document.createElement("div"));
    handle.style.position = "absolute";
    handle.className = "frame-box-handle " + cursor;
    handle.frame_drag_cursor = cursor;

    handle.style.pointerEvents = "all";
    div.appendChild(handle);
    for(s in style)
    {
      handle.style[s] = style[s];
    }
    return handle;
  }

  /* Create the corner handles after the edge handles, so they're on top. */
  create_handle("n-resize", {top: "-5px", width: "100%", height: "10px"});
  create_handle("s-resize", {bottom: "-5px", width: "100%", height: "10px"});
  create_handle("w-resize", {left: "-5px", height: "100%", width: "10px"});
  create_handle("e-resize", {right: "-5px", height: "100%", width: "10px"});
  create_handle("nw-resize", {top: "-5px", left: "-5px", height: "10px", width: "10px"});
  create_handle("ne-resize", {top: "-5px", right: "-5px", height: "10px", width: "10px"});
  create_handle("sw-resize", {bottom: "-5px", left: "-5px", height: "10px", width: "10px"});
  create_handle("se-resize", {bottom: "-5px", right: "-5px", height: "10px", width: "10px"});
}

var apply_drag = function(dragging_mode, x, y, image_dimensions, box)
{
  var move_modes = {
    "move": { left: +1, top: +1, bottom: +1, right: +1 },
    "n-resize": { top: +1 },
    "s-resize": { bottom: +1 },
    "w-resize": { left: +1 },
    "e-resize": { right: +1 },
    "nw-resize": { top: +1, left: +1 },
    "ne-resize": { top: +1, right: +1 },
    "sw-resize": { bottom: +1, left: +1 },
    "se-resize": { bottom: +1, right: +1 }
  }
  var mode = move_modes[dragging_mode];
  var result = {
    left: box.left,
    top: box.top,
    width: box.width,
    height: box.height
  };
  var right = result.left + result.width;
  var bottom = result.top + result.height;

  if(dragging_mode == "move")
  {
    /* In move mode, clamp the movement.  In other modes, clip the size below. */
    x = clamp(x, -result.left, image_dimensions.width-right);
    y = clamp(y, -result.top, image_dimensions.height-bottom);
  }

  /* Apply the drag. */
  if(mode.top != null)     result.top += y * mode.top;
  if(mode.left != null)    result.left += x * mode.left;
  if(mode.right != null)   right += x * mode.right;
  if(mode.bottom != null)  bottom += y * mode.bottom;

  if(dragging_mode != "move")
  {
    /* Only clamp the dimensions that were modified. */
    if(mode.left != null)   result.left = clamp(result.left, 0, right-1);
    if(mode.top != null)    result.top = clamp(result.top, 0, bottom-1);
    if(mode.bottom != null) bottom = clamp(bottom, result.top+1, image_dimensions.height);
    if(mode.right != null)  right = clamp(right, result.left+1, image_dimensions.width);
  }

  result.width = right - result.left;
  result.height = bottom - result.top;
  return result;
}

/*
 * Given a frame, its post and an image, return the frame's rectangle scaled to
 * the size of the image.
 */
var frame_dimensions_to_image = function(frame, image, post)
{
  var result = {
    top: frame.source_top,
    left: frame.source_left,
    width: frame.source_width,
    height: frame.source_height
  };
  result.left *= image.width / post.width;
  result.top *= image.height / post.height;
  result.width *= image.width / post.width;
  result.height *= image.height / post.height;

  result.top = Math.round(result.top); result.left = Math.round(result.left);
  result.width = Math.round(result.width); result.height = Math.round(result.height);

  return result;
}

/*
 * Convert dimensions scaled to an image back to the source resolution.
 */
var frame_dimensions_from_image = function(frame, image, post)
{
  var result = {
    source_top: frame.top,
    source_left: frame.left,
    source_width: frame.width,
    source_height: frame.height
  };

  /* Scale the coordinates back into the source resolution. */
  result.source_top /= image.height / post.height;
  result.source_left /= image.width / post.width;
  result.source_height /= image.height / post.height;
  result.source_width /= image.width / post.width;

  result.source_top = Math.round(result.source_top); result.source_left = Math.round(result.source_left);
  result.source_width = Math.round(result.source_width); result.source_height = Math.round(result.source_height);
  return result;
}

FrameEditor = function(container, image_container, popup_container, options)
{
  this.container = container;
  this.popup_container = popup_container;
  this.image_container = image_container;
  this.options = options;
  this.show_corner_drag = true;

  this.image_frames = [];

  /* Event handlers which are set only while the tag editor is open: */
  this.open_handlers = [];

  /* Set up the four parts of the corner dragger. */
  var popup_parts = [".frame-editor-nw", ".frame-editor-ne", ".frame-editor-sw", ".frame-editor-se"];
  this.corner_draggers = [];
  for(var i = 0; i < popup_parts.length; ++i)
  {
    var part = popup_parts[i];
    var div = this.popup_container.down(part);
    var corner_dragger = new CornerDragger(div, part, {
      onUpdate: function() {
        this.update_frame_in_list(this.editing_frame);
        this.update_image_frame(this.editing_frame);
      }.bind(this)
    });
    this.corner_draggers.push(corner_dragger);
  }

  /* Create the main frame.  This sits on top of the image, receives mouse events and
   * holds the individual frames. */
  var div = $(document.createElement("div"));
  div.style.position = "absolute";
  div.style.left = "0";
  div.style.top = "0";
  div.className = "frame-editor-main-frame";
  this.image_container.appendChild(div);
  this.main_frame = div;
  this.main_frame.hide();

  /* Frame editor buttons: */
  this.container.down(".frame-editor-add").on("click", function(e) { e.stop(); this.add_frame(); }.bindAsEventListener(this));

  /* Buttons in the frame table: */
  this.container.on("click", ".frame-label", function(e, element) {
    e.stop();
    var frame_idx = element.up(".frame-row").frame_idx;
    this.focus(frame_idx);
  }.bind(this));

  this.container.on("click", ".frame-delete", function(e, element) {
    e.stop();
    var frame_idx = element.up(".frame-row").frame_idx;
    this.delete_frame(frame_idx);
  }.bind(this));

  this.container.on("click", ".frame-up", function(e, element) {
    e.stop();
    var frame_idx = element.up(".frame-row").frame_idx;
    this.move_frame(frame_idx, frame_idx-1);
  }.bind(this));

  this.container.on("click", ".frame-down", function(e, element) {
    e.stop();
    var frame_idx = element.up(".frame-row").frame_idx;
    this.move_frame(frame_idx, frame_idx+1);
  }.bind(this));

  this.container.down("table").on("change", function(e) {
    this.form_data_changed();
  }.bind(this));
}

FrameEditor.prototype.move_frame = function(frame_idx, frame_idx_target)
{
  var post = Post.posts.get(this.post_id);

  frame_idx_target = Math.max(frame_idx_target, 0);
  frame_idx_target = Math.min(frame_idx_target, post.frames_pending.length-1);
  if(frame_idx == frame_idx_target)
    return;

  var frame = post.frames_pending[frame_idx];
  post.frames_pending.splice(frame_idx, 1);
  post.frames_pending.splice(frame_idx_target, 0, frame);

  this.repopulate_table();

  /* Reset the focus.  If the item that was moved was focused, focus on it in
   * its new position. */
  var editing_frame = this.editing_frame == frame_idx? frame_idx_target:this.editing_frame;
  this.editing_frame = null;
  this.focus(editing_frame);
}

FrameEditor.prototype.form_data_changed = function()
{
  var post = Post.posts.get(this.post_id);
  for(var i = 0; i < post.frames_pending.length; ++i)
    this.update_frame_from_list(i);
  this.update();
}

FrameEditor.prototype.set_drag_to_create = function(enable)
{
  this.drag_to_create = enable;
}

FrameEditor.prototype.update_show_corner_drag = function()
{
  var shown = this.post_id != null && this.editing_frame != null && this.show_corner_drag;
  if(Prototype.Browser.WebKit)
  {
    /* Work around a WebKit (maybe just a Chrome) issue.  Images are downloaded immediately, but
     * they're only decompressed the first time they're actually painted on screen.  This happens
     * late, after all style is applied: hiding with display: none, visibility: hidden or even
     * opacity: 0 causes the image to not be decoded until it's displayed, which causes a huge
     * UI hitch the first time the user drags a box.  Work around this by setting opacity very
     * small; it'll trick it into decoding the image, but it'll clip to 0 when rendered. */
    if(shown)
    {
      this.popup_container.style.opacity = 1;
      this.popup_container.style.pointerEvents = "";
      this.popup_container.style.position = "static";
    }
    else
    {
      this.popup_container.style.opacity = 0.001;

      /* Make sure the invisible element doesn't interfere with the page; disable pointer-events
       * so it doesn't receive clicks, and set it to absolute so it doesn't affect the size of its
       * containing box. */
      this.popup_container.style.pointerEvents = "none";
      this.popup_container.style.position = "absolute";
      this.popup_container.style.top = "0px";
      this.popup_container.style.right = "0px";
    }
    this.popup_container.show();
  }
  else
  {
    this.popup_container.show(shown);
  }

  for(var i = 0; i < this.corner_draggers.length; ++i)
    this.corner_draggers[i].update();
}

FrameEditor.prototype.set_show_corner_drag = function(enable)
{
  this.show_corner_drag = enable;
  this.update_show_corner_drag();
}

FrameEditor.prototype.set_image_dimensions = function(width, height)
{
  var editing_frame = this.editing_frame;
  var post_id = this.post_id;

  this.close();

  this.image_dimensions = {width: width, height: height};
  this.main_frame.style.width = this.image_dimensions.width + "px";
  this.main_frame.style.height = this.image_dimensions.height + "px";

  if(post_id != null)
  {
    this.open(post_id);
    this.focus(editing_frame);
  }
}

/*
 * Like document.elementFromPoint, but returns an array of all elements at the given point.
 * If a top element is specified, stop if it's reached without including it in the list.
 *
 */
var elementArrayFromPoint = function(x, y, top)
{
  var elements = [];
  while(1)
  {
    var element = document.elementFromPoint(x, y);
    if(element == this.main_frame || element == document.documentElement)
      break;
    element.original_display = element.style.display;
    element.style.display = "none";
    elements.push(element);
  }

  /* Restore the elements we just hid. */
  elements.each(function(e) {
    e.style.display = e.original_display;
    e.original_display = null;
  });

  return elements;
}

FrameEditor.prototype.is_opened = function()
{
  return this.post_id != null;
}

/* Open the frame editor if it isn't already, and focus on the specified frame. */
FrameEditor.prototype.open = function(post_id)
{
  if(this.image_dimensions == null)
    throw "Must call set_image_dimensions before open";
  if(this.post_id != null)
    return;
  this.post_id = post_id;
  this.editing_frame = null;
  this.dragging_item = null;

  this.container.show();
  this.main_frame.show();
  this.update_show_corner_drag();

  var post = Post.posts.get(this.post_id);

  /* Tell the corner draggers which post we're working on now, so they'll start
   * loading the JPEG version immediately if necessary.  Otherwise, we'll start
   * loading it the first time we focus a frame, which will hitch the editor for
   * a while in Chrome. */
  for(var i = 0; i < this.corner_draggers.length; ++i)
    this.corner_draggers[i].set_post_id(this.post_id);

  this.open_handlers.push(
    document.on("keydown", function(e) {
      if (e.keyCode == Event.KEY_ESC) { this.discard(); }
    }.bindAsEventListener(this))
  )

  /* If we havn't done so already, make a backup of this post's frames.  We'll restore
   * from this later if the user cancels the edit. */
  this.original_frames = Object.toJSON(post.frames_pending);

  this.repopulate_table();

  this.create_dragger();

  if(post.frames_pending.length > 0)
    this.focus(0);

  this.update();
}

FrameEditor.prototype.create_dragger = function()
{
  if(this.dragger)
    this.dragger.destroy();

  this.dragger = new DragElement(this.main_frame, {
    ondown: function(e) {
      var post = Post.posts.get(this.post_id);

      /*
       * Figure out which element(s) we're clicking on.  The click may lie on a spot
       * where multiple frames overlap; make a list.
       *
       * Temporarily enable pointerEvents on the frames, so elementFromPoint will
       * resolve them.
       */
      this.image_frames.each(function(frame) { frame.style.pointerEvents = "all"; });
      var clicked_elements = elementArrayFromPoint(e.x, e.y, this.main_frame);
      this.image_frames.each(function(frame) { frame.style.pointerEvents = "none"; });

      /* If we clicked on a handle, prefer it over frame bodies at the same spot. */
      var element = null;
      clicked_elements.each(function(e) {
        /* If a handle was clicked, always prefer it.  Use the first handle we find,
         * so we prefer the corner handles (which are always on top) to edge handles. */
        if(element == null && e.hasClassName("frame-box-handle"))
          element = e;
      }.bind(this));

      /* If a handle wasn't clicked, prefer the frame that's currently focused. */
      if(element == null)
      {
        clicked_elements.each(function(e) {
          if(!e.hasClassName("frame-editor-frame-box"))
            e = e.up(".frame-editor-frame-box");
          if(this.image_frames.indexOf(e) == this.editing_frame)
            element = e;
        }.bind(this));
      }

      /* Otherwise, just use the first item that was found. */
      if(element == null)
        element = clicked_elements[0];

      /* If a handle was clicked on, find the frame element that contains it. */
      var frame_element = element;
      if(!frame_element.hasClassName("frame-editor-frame-box"))
        frame_element = frame_element.up(".frame-editor-frame-box");

      /* If we didn't click on a frame box at all, create a new one. */
      if(frame_element == null)
      {
        if(!this.drag_to_create)
          return;

        this.dragging_new = true;
      }
      else
        this.dragging_new = false;

      /* If the element we actually clicked on was one of the edge handles, set the drag
       * mode based on which one was clicked. */
      if(element.hasClassName("frame-box-handle"))
        this.dragging_mode = element.frame_drag_cursor
      else
        this.dragging_mode = "move";

      if(frame_element && frame_element.hasClassName("frame-editor-frame-box"))
      {
        var frame_idx = this.image_frames.indexOf(frame_element);
        this.dragging_idx = frame_idx;

        var frame = post.frames_pending[this.dragging_idx];
        this.dragging_anchor = frame_dimensions_to_image(frame, this.image_dimensions, post);
      }

      this.focus(this.dragging_idx);

      /* If we're dragging a handle, override the drag class so the pointer will
       * use the handle pointer instead of the drag pointer. */
      this.dragger.overriden_drag_class = this.dragging_mode == "move"? null: this.dragging_mode;

      this.dragger.options.snap_pixels = this.dragging_new? 10:0;

      /* Stop propagation of the event, so any other draggers in the chain don't start.  In
       * particular, when we're dragging inside the image, we need to stop WindowDragElementAbsolute.
       * Only do this if we're actually dragging, not if we aborted due to this.drag_to_create. */
      e.latest_event.stopPropagation();
    }.bind(this),

    onup: function(e) {
      this.dragging_idx = null;
      this.dragging_anchor = null;
    }.bind(this),

    ondrag: function(e) {
      var post = Post.posts.get(this.post_id);

      if(this.dragging_new)
      {
        /* Pick a dragging mode based on which way we were dragged.  This is a
         * little funny; we should probably be able to drag freely, not be fixed
         * to the first direction we drag. */
        if(e.aX > 0 && e.aY > 0)        this.dragging_mode = "se-resize";
        else if(e.aX > 0 && e.aY < 0)   this.dragging_mode = "ne-resize";
        else if(e.aX < 0 && e.aY > 0)   this.dragging_mode = "sw-resize";
        else if(e.aX < 0 && e.aY < 0)   this.dragging_mode = "nw-resize";
        else return;

        this.dragging_new = false;

        /* Create a new, empty frame.  When we get to the regular drag path below we'll
         * give it its real size, based on how far we've dragged so far. */
        var frame_offset = this.main_frame.cumulativeOffset();
        var dims = {
          left: e.dragger.anchor_x - frame_offset.left,
          top: e.dragger.anchor_y - frame_offset.top,
          height: 0,
          width: 0
        };
        this.dragging_anchor = dims;

        var source_dims = frame_dimensions_from_image(dims, this.image_dimensions, post);
        this.dragging_idx = this.add_frame(source_dims);
        post.frames_pending[this.editing_frame] = source_dims;
      }

      if(this.dragging_idx == null)
        return;

      var dims = apply_drag(this.dragging_mode, e.aX, e.aY, this.image_dimensions, this.dragging_anchor);

      /* Scale the changed dimensions back to the source resolution and apply them
       * to the frame. */
      var source_dims = frame_dimensions_from_image(dims, this.image_dimensions, post);
      post.frames_pending[this.editing_frame] = source_dims;

      this.update_frame_in_list(this.editing_frame);
      this.update_image_frame(this.editing_frame);
    }.bind(this)
  });
}

FrameEditor.prototype.repopulate_table = function()
{
  var post = Post.posts.get(this.post_id);

  /* Clear the table. */
  var tbody = this.container.down(".frame-list").down("TBODY");
  while(tbody.firstChild)
    tbody.removeChild(tbody.firstChild);

  /* Clear the image frames. */
  this.image_frames.each(function(f) {
    f.parentNode.removeChild(f);
  }.bind(this));
  this.image_frames = [];

  for(var i = 0; i < post.frames_pending.length; ++i)
  {
    this.add_frame_to_list(i);
    this.create_image_frame();
    this.update_image_frame(i);
  }
}

FrameEditor.prototype.update = function()
{
  this.update_show_corner_drag();

  if(this.image_dimensions == null)
    return;

  var post = Post.posts.get(this.post_id);
  if(post != null)
  {
    for(var i = 0; i < post.frames_pending.length; ++i)
      this.update_image_frame(i);
  }
}

/* If the frame editor is open, discard changes and close it. */
FrameEditor.prototype.discard = function()
{
  if(this.post_id == null)
    return;

  /* Save revert_to, and close the editor before reverting, to make sure closing
   * the editor doesn't change anything. */
  var revert_to = this.original_frames;
  var post_id = this.post_id;
  this.close();

  /* Revert changes. */
  var post = Post.posts.get(post_id);
  post.frames_pending = revert_to.evalJSON();
}

/* Get the frames specifier for the post's frames. */
FrameEditor.prototype.get_current_frames_spec = function()
{
  var post = Post.posts.get(this.post_id);
  var frame = post.frames_pending;
  var frame_specs = [];
  post.frames_pending.each(function(frame) {
    var s = frame.source_left + "x" + frame.source_top + "," + frame.source_width + "x" + frame.source_height;
    frame_specs.push(s);
  }.bind(this));
  return frame_specs.join(";");
}


/* Return true if the frames have been changed. */
FrameEditor.prototype.changed = function()
{
  var post = Post.posts.get(this.post_id);
  var spec = this.get_current_frames_spec();
  return spec != post.frames_pending_string;
}

/* Save changes to the post, if any.  If not null, call finished on completion. */
FrameEditor.prototype.save = function(finished)
{
  if(this.post_id == null)
  {
    if(finished)
      finished();
    return;
  }

  /* Save the current post_id, so it's preserved when the AJAX completion function
   * below is run. */
  var post_id = this.post_id;
  var post = Post.posts.get(post_id);
  var frame = post.frames_pending;

  var spec = this.get_current_frames_spec();
  if(spec == post.frames_pending_string)
  {
    if(finished)
      finished();
    return;
  }

  Post.update_batch([{
    id: post_id,
    frames_pending_string: spec
  }], function(posts)
  {
    if(this.post_id == post_id)
    {
      /* The registered post has been changed, and we're still displaying it.  Grab the
       * new version, and updated original_frames so we no longer consider this post
       * changed. */
      var post = Post.posts.get(post_id);
      this.original_frames = Object.toJSON(post.frames_pending);

      /* In the off-chance that the frames_pending that came back differs from what we
       * requested, update the display. */
      this.update();
    }

    if(finished)
      finished();
  }.bind(this));
}

FrameEditor.prototype.create_image_frame = function()
{
  var div = $(document.createElement("div"));
  div.className = "frame-editor-frame-box";

  /* Disable pointer-events on the image frame, so the handle cursors always
   * show up even when an image frame lies on top of it. */
  div.style.pointerEvents = "none";

  // div.style.opacity=0.1;
  this.main_frame.appendChild(div);
  this.image_frames.push(div);

  create_drag_box(div);


}

FrameEditor.prototype.update_image_frame = function(frame_idx)
{
  var post = Post.posts.get(this.post_id);
  var frame = post.frames_pending[frame_idx];

  /* If the focused frame is being modified, update the corner dragger as well. */
  if(frame_idx == this.editing_frame)
  {
    for(var i = 0; i < this.corner_draggers.length; ++i)
      this.corner_draggers[i].update();
  }

  var dimensions = frame_dimensions_to_image(frame, this.image_dimensions, post);

  var div = this.image_frames[frame_idx];
  div.style.left = dimensions.left + "px";
  div.style.top = dimensions.top + "px";
  div.style.width = dimensions.width + "px";
  div.style.height = dimensions.height + "px";

  if(frame_idx == this.editing_frame)
    div.addClassName("focused-frame-box");
  else
    div.removeClassName("focused-frame-box");
}

/* Append the given frame to the editor list. */
FrameEditor.prototype.add_frame_to_list = function(frame_idx)
{
  var tbody = this.container.down(".frame-list").down("TBODY");
  var tr = $(document.createElement("TR"));
  tr.className = "frame-row frame-" + frame_idx;
  tr.frame_idx = frame_idx;
  tbody.appendChild(tr);

  var html = "<td><span class='frame-label'>Frame " + frame_idx + "</span></td>";
  html += "<td><input class='frame-left frame-dims' size=4></td>";
  html += "<td><input class='frame-top frame-dims' size=4></td>";
  html += "<td><input class='frame-width frame-dims' size=4></td>";
  html += "<td><input class='frame-height frame-dims' size=4></td>";
  html += "<td><a class='frame-delete frame-button-box' href='#'>X</a></td>";
  html += "<td><a class='frame-up frame-button-box' href='#'>⇡</a></td>";
  html += "<td><a class='frame-down frame-button-box' href='#'>⇣</a></td>";
  tr.innerHTML = html;

  this.update_frame_in_list(frame_idx);
}

/* Update the fields of frame_idx in the table. */
FrameEditor.prototype.update_frame_in_list = function(frame_idx)
{
  var post = Post.posts.get(this.post_id);
  var frame = post.frames_pending[frame_idx];

  var tbody = this.container.down(".frame-list").down("TBODY");
  var tr = tbody.down(".frame-" + frame_idx);

  tr.down(".frame-left").value = frame.source_left;
  tr.down(".frame-top").value = frame.source_top;
  tr.down(".frame-width").value = frame.source_width;
  tr.down(".frame-height").value = frame.source_height;
}

/* Commit changes in the frame list to the frame. */
FrameEditor.prototype.update_frame_from_list = function(frame_idx)
{
  var post = Post.posts.get(this.post_id);
  var frame = post.frames_pending[frame_idx];

  var tbody = this.container.down(".frame-list").down("TBODY");
  var tr = tbody.down(".frame-" + frame_idx);

  frame.source_left = tr.down(".frame-left").value;
  frame.source_top = tr.down(".frame-top").value;
  frame.source_width = tr.down(".frame-width").value;
  frame.source_height = tr.down(".frame-height").value;
}

/* Add a new default frame to the end of the list, update the table, and edit the new frame. */
FrameEditor.prototype.add_frame = function(new_frame)
{
  var post = Post.posts.get(this.post_id);

  if(new_frame == null)
    new_frame = {
      source_top: post.height * 1/4,
      source_left: post.width * 1/4,
      source_width: post.width / 2,
      source_height: post.height / 2
    };

  post.frames_pending.push(new_frame);
  this.add_frame_to_list(post.frames_pending.length-1);
  this.create_image_frame();
  this.update_image_frame(post.frames_pending.length-1);

  this.focus(post.frames_pending.length-1);
  return post.frames_pending.length-1;
}

/* Delete the specified frame. */
FrameEditor.prototype.delete_frame = function(frame_idx)
{
  var post = Post.posts.get(this.post_id);

  /* If we're editing this frame, switch to a nearby one. */
  var switch_to_frame = null;
  if(this.editing_frame == frame_idx)
  {
    switch_to_frame = this.editing_frame;
    this.focus(null);

    /* If we're deleting the bottom item on the list, switch to the item above it instead. */
    if(frame_idx == post.frames_pending.length-1)
      --switch_to_frame;

    /* If that put it over the top, we're deleting the only item.  Focus no item. */
    if(switch_to_frame < 0)
      switch_to_frame = null;
  }

  /* Remove the frame from the array. */
  post.frames_pending.splice(frame_idx, 1);

  /* Renumber the table. */
  this.repopulate_table();

  /* Focus switch_to_frame, if any. */
  this.focus(switch_to_frame);
}

FrameEditor.prototype.focus = function(post_frame)
{
  if(this.editing_frame == post_frame)
    return;

  if(this.editing_frame != null)
  {
    var row = this.container.down(".frame-" + this.editing_frame);
    row.removeClassName("frame-focused");
  }

  this.editing_frame = post_frame;

  if(this.editing_frame != null)
  {
    var row = this.container.down(".frame-" + this.editing_frame);
    row.addClassName("frame-focused");
  }

  for(var i = 0; i < this.corner_draggers.length; ++i)
    this.corner_draggers[i].set_post_frame(this.editing_frame);

  this.update();
}

/* Close the frame editor.  Local changes are not saved or reverted. */
FrameEditor.prototype.close = function()
{
  if(this.post_id == null)
    return;
  this.post_id = null;

  this.editing_frame = null;

  for(var i = 0; i < this.corner_draggers.length; ++i)
    this.corner_draggers[i].set_post_id(null);

  if(this.keydown_handler)
  {
    this.open_handlers.each(function(h) { h.stop(); });
    this.open_handlers = [];
  }

  if(this.dragger)
    this.dragger.destroy();
  this.dragger = null;

  this.container.hide();
  this.main_frame.hide();
  this.update_show_corner_drag();

  /* Clear the row table. */
  var tbody = this.container.down(".frame-list").down("TBODY");
  while(tbody.firstChild)
    tbody.removeChild(tbody.firstChild);

  this.original_frames = null;
  this.update();

  if(this.options.onClose)
    this.options.onClose(this);
}

/* Create the specified corner dragger. */
CornerDragger = function(container, part, options)
{
  this.container = container;
  this.part = part;
  this.options = options;

  var box = container.down(".frame-editor-popup-div");

  /* Create a div inside each .frame-editor-popup-div floating on top of the image
   * to show the border of the frame. */
  var frame_box = $(document.createElement("div"));
  frame_box.className = "frame-editor-frame-box";
  create_drag_box(frame_box);
  box.appendChild(frame_box);

  this.dragger = new DragElement(box, {
    snap_pixels: 0,

    ondown: function(e) {
      var element = document.elementFromPoint(e.x, e.y);

      /* If we clicked on a drag handle, use that handle.  Otherwise, choose the corner drag
       * handle for the corner we're in. */
      if(element.hasClassName("frame-box-handle")) this.dragging_mode = element.frame_drag_cursor;
      else if(part == ".frame-editor-nw") this.dragging_mode = "nw-resize";
      else if(part == ".frame-editor-ne") this.dragging_mode = "ne-resize";
      else if(part == ".frame-editor-sw") this.dragging_mode = "sw-resize";
      else if(part == ".frame-editor-se") this.dragging_mode = "se-resize";

      var post = Post.posts.get(this.post_id);
      var frame = post.frames_pending[this.post_frame];
      this.dragging_anchor = frame_dimensions_to_image(frame, this.image_dimensions, post);

      /* When dragging a handle, hide the cursor to get it out of the way. */
      this.dragger.overriden_drag_class = this.dragging_mode == "move"? null: "hide-cursor";

      /* Stop propagation of the event, so any other draggers in the chain don't start.  In
       * particular, when we're dragging inside the image, we need to stop WindowDragElementAbsolute.
       * Only do this if we're actually dragging, not if we aborted due to this.drag_to_create. */
      e.latest_event.stopPropagation();
    }.bind(this),

    ondrag: function(e) {
      var post = Post.posts.get(this.post_id);

      /* Invert the motion, since we're dragging the image around underneith the
       * crop frame instead of dragging the crop frame around. */
      var dims = apply_drag(this.dragging_mode, -e.aX, -e.aY, this.image_dimensions, this.dragging_anchor);

      /* Scale the changed dimensions back to the source resolution and apply them
       * to the frame. */
      var source_dims = frame_dimensions_from_image(dims, this.image_dimensions, post);
      post.frames_pending[this.post_frame] = source_dims;

      if(this.options.onUpdate)
        this.options.onUpdate();
    }.bind(this)
  });

  this.update();
}

/*
 * Set the post to show in the corner dragger.  If post_id is null, clear any displayed
 * post.
 *
 * When the post ID is set, the post frame is always cleared.
 */
CornerDragger.prototype.set_post_id = function(post_id)
{
  this.post_id = post_id;
  this.post_frame = null;

  var url = null;
  var img = this.container.down("img");
  if(post_id != null)
  {
    var post = Post.posts.get(this.post_id);
    this.image_dimensions = {
      width: post.jpeg_width, height: post.jpeg_height
    };

    url = post.jpeg_url;
    img.width = this.image_dimensions.width;
    img.height = this.image_dimensions.height;
  }

  /* Don't change the image if it's already set; it causes Chrome to reprocess the
   * image. */
  if(img.src != url)
  {
    img.src = url;
  
    if(Prototype.Browser.WebKit && url)
    {
      /* Decoding in Chrome takes long enough to be visible.  Hourglass the cursor while it runs. */
      document.documentElement.addClassName("hourglass");
      (function() { document.documentElement.removeClassName("hourglass"); }.defer());
    }
  }

  this.update();
}

CornerDragger.prototype.set_post_frame = function(post_frame)
{
  this.post_frame = post_frame;

  this.update();
}

CornerDragger.prototype.update = function()
{
  if(this.post_id == null || this.post_frame == null)
    return;

  var post = Post.posts.get(this.post_id);
  var frame = post.frames_pending[this.post_frame];
  var dims = frame_dimensions_to_image(frame, this.image_dimensions, post);

  var div = this.container;

  /* Update the drag/frame box. */
  var box = this.container.down(".frame-editor-frame-box");
  box.style.left = dims.left + "px";
  box.style.top = dims.top + "px";
  box.style.width = dims.width + "px";
  box.style.height = dims.height + "px";

  /* Recenter the corner box. */
  var top = dims.top;
  var left = dims.left;
  if(this.part == ".frame-editor-ne" || this.part == ".frame-editor-se")
    left += dims.width;
  if(this.part == ".frame-editor-sw" || this.part == ".frame-editor-se")
    top += dims.height;

  var offset_height = div.offsetHeight/2;
  var offset_width = div.offsetWidth/2;
  /*
  if(this.part == ".frame-editor-nw" || this.part == ".frame-editor-ne") offset_height -= div.offsetHeight/4;
  if(this.part == ".frame-editor-sw" || this.part == ".frame-editor-se") offset_height += div.offsetHeight/4;
  if(this.part == ".frame-editor-nw" || this.part == ".frame-editor-sw") offset_width -= div.offsetWidth/4;
  if(this.part == ".frame-editor-ne" || this.part == ".frame-editor-se") offset_width += div.offsetWidth/4;
  */
  left -= offset_width;
  top -= offset_height;

  /* If the region is small enough that we don't have enough to fill the corner
   * frames, push the frames inward so they line up. */
  if(this.part == ".frame-editor-nw" || this.part == ".frame-editor-sw")
    left = Math.min(left, dims.left + dims.width/2 - div.offsetWidth);
  if(this.part == ".frame-editor-ne" || this.part == ".frame-editor-se")
    left = Math.max(left, dims.left + dims.width/2);
  if(this.part == ".frame-editor-nw" || this.part == ".frame-editor-ne")
    top = Math.min(top, dims.top + dims.height/2 - div.offsetHeight);
  if(this.part == ".frame-editor-sw" || this.part == ".frame-editor-se")
    top = Math.max(top, dims.top + dims.height/2);

  var img = this.container.down(".frame-editor-popup-div");
  img.style.marginTop = (-top) + "px";
  img.style.marginLeft = (-left) + "px";
}



var PostUploadForm = function(form, progress)
{
  var XHRLevel2 = "XMLHttpRequest" in window && (new XMLHttpRequest().upload != null);
  var SupportsFormData = "FormData" in window;
  if(!XHRLevel2 || !SupportsFormData)
    return;
  
  this.form_element = form;
  this.cancel_element = this.form_element.down(".cancel");

  this.progress = progress;
  this.document_title = document.documentElement.down("TITLE");
  this.document_title_orig = this.document_title.textContent;
  this.current_request = null;
  this.form_element.on("submit", this.form_submit_event.bindAsEventListener(this));
  this.cancel_element.on("click", this.click_cancel.bindAsEventListener(this));

  var keypress_event_name = window.opera || Prototype.Browser.Gecko? "keypress":"keydown";
  document.on(keypress_event_name, this.document_keydown_event.bindAsEventListener(this));
}

PostUploadForm.prototype.set_progress = function(f)
{
  var percent = f * 100;
  this.progress.down(".upload-progress-bar-fill").style.width = percent + "%";
  this.document_title.textContent = this.document_title_orig + " (" + percent.toFixed(0) + "%)";
}

PostUploadForm.prototype.request_starting = function()
{
  this.form_element.down(".submit").hide();
  this.cancel_element.show();
  this.progress.show();
  document.documentElement.addClassName("progress");
}

PostUploadForm.prototype.request_ending = function()
{
  this.form_element.down(".submit").show();
  this.cancel_element.hide();
  this.progress.hide();
  this.document_title.textContent = this.document_title_orig;
  document.documentElement.removeClassName("progress");
}

PostUploadForm.prototype.document_keydown_event = function(e)
{
  var key = e.charCode;
  if(!key)
    key = e.keyCode; /* Opera */
  if(key != Event.KEY_ESC)
    return;
  this.cancel();
}

PostUploadForm.prototype.click_cancel = function(e)
{
  e.stop();
  this.cancel();
}


PostUploadForm.prototype.form_submit_event = function(e)
{
  /* This submit may have been stopped by User.run_login_onsubmit. */
  if(e.stopped)
    return;

  if(this.current_request != null)
    return;

  $("post-exists").hide();
  $("post-upload-error").hide();

  /* If the files attribute isn't supported, or we have no file (source upload), use regular
   * form submission. */
  var post_file = $("post_file");
  if(post_file.files == null || post_file.files.length == 0)
    return;

  e.stop();

  this.set_progress(0);
  this.request_starting();

  var form_data = new FormData(this.form_element);

  var onprogress = function(e)
  {
    var done = e.loaded;
    var total = e.total;
    this.set_progress(total? (done/total):1);
  }.bind(this);

  this.current_request = new Ajax.Request("/post/create.json", {
    contentType: null,
    method: "post",
    postBody: form_data,
    onCreate: function(resp)
    {
      var xhr = resp.request.transport;
      xhr.upload.onprogress = onprogress;
    },

    onComplete: function(resp)
    {
      this.current_request = null;
      this.request_ending();

      var json = resp.responseJSON;
      if(!json)
        return;

      if(!json.success)
      {
        if(json.location)
        {
          var a = $("post-exists-link");
          a.setTextContent("post #" + json.post_id);
          a.href = json.location;
          $("post-exists").show();
          return;
        }

        $("post-upload-error").setTextContent(json.reason);
        $("post-upload-error").show();

        return;
      }

      /* If a post/similar link was given and similar results exists, go to them.  Otherwise,
       * go to the new post. */
      var target = json.location;
      if(json.similar_location && json.has_similar_hits)
        target = json.similar_location;
      window.location.href = target;
    }.bind(this)
  });
}

/* Cancel the running request, if any. */
PostUploadForm.prototype.cancel = function()
{
  if(this.current_request == null)
    return;

  /* Don't clear this.current_request; it'll be done by the onComplete callback. */
  this.current_request.transport.abort();
}

/*
 * When file_field is changed to an image, run an image search and put a summary in
 * results.
 */
UploadSimilarSearch = function(file_field, results)
{
  if(!ThumbnailUserImage)
    return;

  this.file_field = file_field;
  this.results = results;

  file_field.on("change", this.field_changed_event.bindAsEventListener(this));
}

UploadSimilarSearch.prototype.field_changed_event = function(event)
{
  this.results.hide();

  if(this.file_field.files == null || this.file_field.files.length == 0)
    return;

  this.results.innerHTML = "Searching...";
  this.results.show();

  var file = this.file_field.files[0];
  var similar = new ThumbnailUserImage(file, this.thumbnail_complete.bind(this));
}

UploadSimilarSearch.prototype.thumbnail_complete = function(result)
{
  if(!result.success)
  {
    this.results.innerHTML = "Image load failed.";
    this.results.show();
    return;
  }

  /* Grab a data URL from the canvas; this is what we'll send to the server. */
  var data_url = result.canvas.toDataURL();

  /* Create the FormData containing the thumbnail image we're sending. */
  var form_data = new FormData();
  form_data.append("url", data_url);

  var req = new Ajax.Request("/post/similar.json", {
    method: "post",
    postBody: form_data,

    /* Tell Prototype not to change XHR's contentType; it breaks FormData. */
    contentType: null,

    onComplete: function(resp)
    {
      this.results.innerHTML = "";
      this.results.show();

      var json = resp.responseJSON;
      if(!json.success)
      {
        this.results.innerHTML = json.reason;
        return;
      }

      if(json.posts.length > 0)
      {
        var posts = [];
        var shown_posts = 3;
        json.posts.slice(0, shown_posts).each(function(post) {
            var url;
            if(User.get_use_browser())
              url = "/post/browse#" + post.id;
            else
              url = "/post/show/" + post.id;
            var s = "<a href='" + url + "'>post #" + post.id + "</a>";
            posts.push(s);
        });
        var post_links = posts.join(", ");
        var see_all = "<a href='/post/similar?search_id=" + json.search_id + "'>(see all)</a>";
        var html = "Similar posts " + see_all + ": " + post_links;

        if(json.posts.length > shown_posts)
        {
          var remaining_posts = json.posts.length - shown_posts;
          html += " (" + remaining_posts + " more)";
        }

        this.results.innerHTML = html;
      }
      else
      {
        this.results.innerHTML = "No similar posts found.";
      }
    }.bind(this)
  });
}



PostModeMenu = {
  mode: "view",

  init: function(pool_id) {
    try {	/* This part doesn't work on IE7; for now, let's allow execution to continue so at least some initialization is run */

    /* If pool_id isn't null, it's the pool that we're currently searching for. */
    this.pool_id = pool_id;

    var color_element = $("mode-box")
    this.original_style = { border: color_element.getStyle("border") }
    
    if (Cookie.get("mode") == "") {
      Cookie.put("mode", "view")
      $("mode").value = "view"
    } else {
      $("mode").value = Cookie.get("mode")
    }

    } catch (e) {}
    
    this.vote_score = Cookie.get("vote")
    if (this.vote_score == "") {
      this.vote_score = 1
      Cookie.put("vote", this.vote_score)
    } else {
      this.vote_score == +this.vote_score
    }
  
    Post.posts.each(function(p) {
      var post_id = p[0]
      var post = p[1]

      var span = $("p" + post.id);
      if(span == null)
        return;

      /* Use post_id here, not post, since the post object can be replaced later after updates. */
      span.down("A").observe("click", function(e) { PostModeMenu.click(e, post_id); });
      span.down("A").observe("mousedown", function(e) { PostModeMenu.post_mousedown(e, post_id); });
      span.down("A").observe("mouseover", function(e) { PostModeMenu.post_mouseover(e, post_id); });
      span.down("A").observe("mouseout", function(e) { PostModeMenu.post_mouseout(e, post_id); });
      span.down("A").observe("mouseup", function(e) { PostModeMenu.post_mouseup(e, post_id); });
    });

    document.observe("mouseup", function(e) { PostModeMenu.post_mouseup(e, null); });
    Event.observe(window, "pagehide", function(e) { PostModeMenu.post_end_drag(); });

    this.change()  
  },

  set_vote: function(score) {
    this.vote_score = score
    Cookie.put("vote", this.vote_score)
    Post.update_vote_widget('vote-menu', this.vote_score);
  },

  get_style_for_mode: function(s)
  {
    if (s == "view") {
      return {background: ""};
    } else if (s == "edit") {
      return {background: "#3A3"}
    } else if (s == "rating-q") {
      return {background: "#AAA"}
    } else if (s == "rating-s") {
      return {background: "#6F6"}
    } else if (s == "rating-e") {
      return {background: "#F66"}
    } else if (s == "vote") {
      return {background: "#FAA"}
    } else if (s == "lock-rating") {
      return {background: "#AA3"}
    } else if (s == "lock-note") {
      return {background: "#3AA"}
    } else if (s == "approve") {
      return {background: "#26A"}
    } else if (s == "flag") {
      return {background: "#F66"}
    } else if (s == "add-to-pool") {
      return {background: "#26A"}
    } else if (s == "apply-tag-script") {
      return {background: "#A3A"}
    } else if (s == "reparent-quick") {
      return {background: "#CCA"}
    } else if (s == "remove-from-pool") {
      return {background: "#CCA"}
    } else if (s == 'reparent') {
      return {background: "#0C0"}
    } else if (s == 'dupe') {
      return {background: "#0C0"}
    } else {
      return {background: "#AFA"}
    }
  },

  change: function() {
    if(!$("mode"))
      return;
    var s = $F("mode")
    Cookie.put("mode", s, 7)

    PostModeMenu.mode = s

    if (s.value != "edit") {
      $("quick-edit").hide()
    }
    if (s.value != "apply-tag-script") {
      $("edit-tag-script").hide()
      Post.reset_tag_script_applied()
    }

    if (s == "vote") {
      Post.update_vote_widget('vote-menu', this.vote_score);
      $("vote-score").show()
    } else if (s == "apply-tag-script") {
      $("edit-tag-script").show()
      $("edit-tag-script").focus()
    }
  },

  click: function(event, post_id) {
    var s = $("mode")
    if(!s)
      return;

    if (s.value == "view") {
      return true
    }

    if (s.value == "edit") {
      post_quick_edit.show(post_id);
    } else if (s.value == 'vote') {
      Post.vote(post_id, this.vote_score)
    } else if (s.value == 'rating-q') {
      Post.update_batch([{id: post_id, rating: "questionable"}]);
    } else if (s.value == 'rating-s') {
      Post.update_batch([{id: post_id, rating: "safe"}]);
    } else if (s.value == 'rating-e') {
      Post.update_batch([{id: post_id, rating: "explicit"}]);
    } else if (s.value == 'reparent') {
      if(post_id == id)
       return false;
      TagScript.run(post_id, "parent:" + id)
    } else if (s.value == 'dupe') {
      if(post_id == id)
       return false;
      TagScript.run(post_id, "duplicate parent:" + id)
    } else if (s.value == 'lock-rating') {
      Post.update_batch([{id: post_id, is_rating_locked: "1"}]);
    } else if (s.value == 'lock-note') {
      Post.update_batch([{id: post_id, is_note_locked: "1"}]);
    } else if (s.value == 'flag') {
      Post.flag(post_id)
    } else if (s.value == "approve") {
      Post.approve(post_id)
    } else if (s.value == 'add-to-pool') {
      Pool.add_post(post_id, 0)
    } else if (s.value == "remove-from-pool") {
      Pool.remove_post(post_id, PostModeMenu.pool_id);
    }

    event.stopPropagation();
    event.preventDefault();
  },

  dragging_from_post: null,
  dragging_active: false,
  dragging_list: null,
  dragging_hash: null,

  post_add_to_hovered_list: function(post_id)
  {
    var element = element = $$("#p" + post_id + " > .directlink");
    if(element.length > 0)
    {
      element[0].addClassName("tag-script-applied");
      Post.applied_list.push(element[0]);
    }

    if(!PostModeMenu.dragging_hash.get(post_id))
    {
      PostModeMenu.dragging_hash.set(post_id, true);
      PostModeMenu.dragging_list.push(post_id);
    }
  },

  post_mousedown: function(event, post_id)
  {
    if(event.button != 0)
      return;

    if(PostModeMenu.mode == "reparent-quick")
    {
      PostModeMenu.dragging_from_post = post_id;
      PostModeMenu.post_begin_drag();
    }
    else if(PostModeMenu.mode == "apply-tag-script")
    {
      Post.reset_tag_script_applied();
      PostModeMenu.dragging_from_post = post_id;
      PostModeMenu.dragging_list = new Array;
      PostModeMenu.dragging_hash = new Hash;
      PostModeMenu.post_add_to_hovered_list(post_id);
    }
    else
      return;

    /* Prevent the mousedown from being processed; this keeps it from turning into
     * a real drag action, which will suppress our mouseover/mouseout messages.  We
     * only do this when the tag script is enabled, so we don't mess with regular
     * clicks. */
    event.preventDefault();
    event.stopPropagation();
  },

  post_begin_drag: function(type)
  {
    document.body.addClassName("dragging-to-post");
  },

  post_end_drag: function()
  {
    document.body.removeClassName("dragging-to-post");
    PostModeMenu.dragging_from_post = null;
  },

  post_mouseup: function(event, post_id)
  {
    if(event.button != 0)
      return;
    if(!PostModeMenu.dragging_from_post)
      return;

    if(PostModeMenu.mode == "reparent-quick")
    {
      if(post_id)
      {
        notice("Updating post");
        Post.update_batch([{ id: PostModeMenu.dragging_from_post, parent_id: post_id}]);
      }

      PostModeMenu.post_end_drag();
      return;
    }
    else if(PostModeMenu.mode == "apply-tag-script")
    {
      if(post_id)
        return;

      /* We clicked or dragged some posts to apply a tag script; process it. */
      var tag_script = TagScript.TagEditArea.value;
      TagScript.run(PostModeMenu.dragging_list, tag_script);

      PostModeMenu.dragging_from_post = null;
      PostModeMenu.dragging_active = false;
      PostModeMenu.dragging_list = null;
      PostModeMenu.dragging_hash = null;
    }
  },

  post_mouseover: function(event, post_id)
  {
    var post = $("p" + post_id);
    var style = PostModeMenu.get_style_for_mode(PostModeMenu.mode)
    post.down("span").setStyle(style)

    if(PostModeMenu.mode != "apply-tag-script")
      return;
    
    if(!PostModeMenu.dragging_from_post)
      return;

    if(post_id != PostModeMenu.dragging_from_post)
      PostModeMenu.dragging_active = true;

    PostModeMenu.post_add_to_hovered_list(post_id);
  },

  post_mouseout: function(event, post_id)
  {
    var post = $("p" + post_id);
    post.down("span").setStyle({background: ""});
  },

  apply_tag_script_to_all_posts: function()
  {
    var tag_script = TagScript.TagEditArea.value;
    var post_ids = Post.posts.inject([], function(list, pair) {
      list.push(pair[0]);
      return list;
    });

    TagScript.run(post_ids, tag_script);
  }
}

TagScript = {
  TagEditArea: null,

  load: function() {
    this.TagEditArea.value = Cookie.get("tag-script")
  },
  save: function() {
    Cookie.put("tag-script", this.TagEditArea.value)
  },

  init: function(element, x) {
    this.TagEditArea = element

    TagScript.load()

    this.TagEditArea.observe("change", function(e) { TagScript.save() })
    this.TagEditArea.observe("focus", function(e) { Post.reset_tag_script_applied() })

    /* This mostly keeps the tag script field in sync between windows, but it
     * doesn't work in Opera, which sends focus events before blur events. */
    document.observe("blur", function(e) { TagScript.save() })
    document.observe("focus", function(e) { TagScript.load() })
  },

  parse: function(script) {
    return script.match(/\[.+?\]|\S+/g)
  },

  test: function(tags, predicate) {
    var split_pred = predicate.match(/\S+/g)
    var is_true = true

    split_pred.each(function(x) {
      if (x[0] == "-") {
        if (tags.include(x.substr(1, 100))) {
          is_true = false
          throw $break
        }
      } else {
        if (!tags.include(x)) {
          is_true = false
          throw $break
        }
      }
    })

    return is_true
  },

  process: function(tags, command) {
    if (command.match(/^\[if/)) {
      var match = command.match(/\[if\s+(.+?)\s*,\s*(.+?)\]/)
      if (TagScript.test(tags, match[1])) {
        return TagScript.process(tags, match[2])
      } else {
        return tags
      }
    } else if (command == "[reset]") {
      return []
    } else if (command[0] == "-" && command.indexOf("-pool:") != 0) {
      return tags.reject(function(x) {return x == command.substr(1, 100)})
    } else {
      tags.push(command)
      return tags
    }
  },

  run: function(post_ids, tag_script, finished) {
    if(!Object.isArray(post_ids))
      post_ids = $A([post_ids]);

    var commands = TagScript.parse(tag_script) || []

    var posts = new Array;
    post_ids.each(function(post_id) {
      var post = Post.posts.get(post_id)
      var old_tags = post.tags.join(" ")

      commands.each(function(x) {
        post.tags = TagScript.process(post.tags, x)
      })

      posts.push({
        id: post_id,
        old_tags: old_tags,
        tags: post.tags.join(" ")
      });
    });

    notice("Updating " + posts.length + (post_ids.length == 1? " post": " posts") );
    Post.update_batch(posts, finished);
  }
}

function PostQuickEdit(container)
{
  this.container = container;
  this.submit_event = this.submit_event.bindAsEventListener(this);

  this.container.down("form").observe("submit", this.submit_event);
  this.container.down(".cancel").observe("click", function(e) {
    e.preventDefault();
    this.hide();
  }.bindAsEventListener(this));
  this.container.down("#post_tags").observe("keydown", function(e) {
    if(e.keyCode == Event.KEY_ESC)
    {
      e.stop();
      this.hide();
      return;
    }

    if(e.keyCode != Event.KEY_RETURN)
      return;
    this.submit_event(e);
  }.bindAsEventListener(this));
}

PostQuickEdit.prototype.show = function(post_id)
{
  Post.hover_info_pin(post_id);

  var post = Post.posts.get(post_id);
  this.post_id = post_id;
  this.old_tags = post.tags.join(" ");

  this.container.down("#post_tags").value = post.tags.join(" ") + " rating:" + post.rating.substr(0, 1) + " ";
  this.container.show();
  this.container.down("#post_tags").focus();
}

PostQuickEdit.prototype.hide = function()
{
  this.container.hide();
  Post.hover_info_pin(null);
}

PostQuickEdit.prototype.submit_event = function(e)
{
  e.stop();
  this.hide();

  Post.update_batch([{id: this.post_id, tags: this.container.down("#post_tags").value, old_tags: this.old_tags}], function() {
    notice("Post updated");
    this.hide();
  }.bind(this));
}



PostTagHistory = {
  last_click: -1,
  checked: [],
  dragging: false,

  init: function() {
    // Watch mousedown events on the table itself, so clicking between table rows and dragging
    // doesn't misbehave.
    $("history").observe("mousedown", function(event) {
      if (!event.shiftKey) {
        // Clear last_click, so dragging will extend from the next position crossed instead of
        // the previous position clicked.
        PostTagHistory.last_click = -1
      }

      PostTagHistory.mouse_is_down();
      event.stopPropagation();
      event.preventDefault();
    }, true)
    PostTagHistory.update()
  },

  add_change: function(id, post_id, user_id) {
    PostTagHistory.checked.push({
      id: id,
      post_id: post_id,
      user_id: user_id,
      on: false,
      row: $("r" + id)
    })
    $("r" + id).observe("mousedown", function(e) { PostTagHistory.mousedown(id, e), true })
    $("r" + id).observe("mouseover", function(e) { PostTagHistory.mouseover(id, e), true })
  },

  update: function() {
    // Set selected flags on selected rows, and remove them from unselected rows.
    for (i = 0; i < PostTagHistory.checked.length; ++i) {
      var row = PostTagHistory.checked[i].row

      if(PostTagHistory.checked[i].on) {
        row.addClassName("selected");
      } else {
        row.removeClassName("selected");
      }
    }

    if (PostTagHistory.count_selected() > 0) {
      $("undo").className = ""
    } else {
      $("undo").className = "footer-disabled"
    }

    if (PostTagHistory.count_selected() == 1) {
      i = PostTagHistory.get_first_selected_row()
      $("revert").href = "post_tag_history/revert?id=" + PostTagHistory.checked[i].id
      $("revert").className = ""
      $("post_id").value = PostTagHistory.checked[i].post_id
      $("user_name").value = PostTagHistory.checked[i].user_id
    } else {
      $("revert").href = "#"
      $("revert").className = "footer-disabled"
    }
  },

  // Return the number of selected items.
  count_selected: function() {
    ret = 0
    for (i = 0; i < PostTagHistory.checked.length; ++i) {
      if (PostTagHistory.checked[i].on)
        ++ret
    }
    return ret;
  },

  // Get the index of the first selected item.
  get_first_selected_row: function() {
    for (i = 0; i < PostTagHistory.checked.length; ++i) {
      if (PostTagHistory.checked[i].on)
        return i;
    }
    return null;
  },

  // Get the index of the item with the specified id.
  get_row_by_id: function(id) {
    for (i = 0; i < PostTagHistory.checked.length; ++i) {
      if (PostTagHistory.checked[i].id == id)
        return i;
    }
    return null;
  },

  // Set [first, last] = on.
  set: function(first, last, on) {
    i = first;
    while(true)
    {
      PostTagHistory.checked[i].on = on;

      if(i == last)
        break;

      i += (last > first)? +1:-1;
    }
  },

  doc_mouseup: function(event) {
    PostTagHistory.dragging = false
    document.stopObserving("mouseup", PostTagHistory.doc_mouseup)
  },

  // The mouse is down, so we're dragging; watch mouseup to know when we've let go.
  mouse_is_down: function() {
    PostTagHistory.dragging = true;
    document.observe("mouseup", PostTagHistory.doc_mouseup)
  },

  mousedown: function(id, event) {
    if (!Event.isLeftClick(event)) {
      return;
    }

    PostTagHistory.mouse_is_down()

    var i = PostTagHistory.get_row_by_id(id)
    if (i == null) {
      return;
    }

    var first = null
    var last = null
    if (PostTagHistory.last_click != -1 && event.shiftKey) {
      first = PostTagHistory.last_click
      last = i
    } else {
      first = last = PostTagHistory.last_click = i
      PostTagHistory.checked[i].on = !PostTagHistory.checked[i].on;
    }

    var on = PostTagHistory.checked[first].on

    if (!event.ctrlKey) {
      PostTagHistory.set(0, PostTagHistory.checked.length-1, false)
    }
    PostTagHistory.set(first, last, on)
    PostTagHistory.update()

    event.stopPropagation();
    event.preventDefault();
  },

  mouseover: function(id, event) {
    var i = PostTagHistory.get_row_by_id(id)
    if (!i) return;

    if (PostTagHistory.last_click == -1) {
      PostTagHistory.last_click = i
    }

    if (!PostTagHistory.dragging) {
      return;
    }

    PostTagHistory.set(0, PostTagHistory.checked.length-1, false)

    first = PostTagHistory.last_click
    last = i
    this_click = i

    PostTagHistory.set(first, last, true)
    PostTagHistory.update()
  },

  undo: function() {
    if (PostTagHistory.count_selected() == 0) {
      return;
    }
    var list = []
    for (i = 0; i < PostTagHistory.checked.length; ++i) {
      if (!PostTagHistory.checked[i].on)
        continue;
      list.push(PostTagHistory.checked[i].id)
    }

    notice("Undoing...");

    new Ajax.Request("/post_tag_history/undo.json", {
      parameters: {
        "id": list.join(",")
      },

      onComplete: function(resp) {
        var resp = resp.responseJSON

        if (resp.success) {
          notice("Changes undone.");
        } else {
          notice("Error: " + resp.reason)
        }
      }
    })
  }
}


var _preload_image_pool = null;

PreloadContainer = function()
{
  /* Initialize the pool the first time we make a container, since we may not
   * have ImgPoolHandler when the file is loaded. */
  if(_preload_image_pool == null)
      _preload_image_pool = new ImgPoolHandler();

  this.container = $(document.createElement("div"));
  this.container.style.display = "none";
  document.body.appendChild(this.container);

  this.active_preloads = 0;

  this.on_image_complete_event = this.on_image_complete_event.bindAsEventListener(this);
}

PreloadContainer.prototype.cancel_preload = function(img)
{
  img.stopObserving();
  this.container.removeChild(img);
  _preload_image_pool.release(img);
  if(img.active)
    --this.active_preloads;
}

PreloadContainer.prototype.preload = function(url)
{
  ++this.active_preloads;

  var imgTag = _preload_image_pool.get();
  imgTag.observe("load", this.on_image_complete_event);
  imgTag.observe("error", this.on_image_complete_event);
  imgTag.src = url;
  imgTag.active = true;

  this.container.appendChild(imgTag);
  return imgTag;
}

/* Return an array of all preloads. */
PreloadContainer.prototype.get_all = function()
{
  return this.container.childElements();
}

PreloadContainer.prototype.destroy = function()
{
  this.get_all().each(function(img) {
    this.cancel_preload(img);
  }.bind(this));

  document.body.removeChild(this.container);
}

PreloadContainer.prototype.on_image_complete_event = function(event)
{
  --this.active_preloads;
  event.target.active = false;
}


Preload = {
  /*
   * Thumbnail preloading.
   *
   * After the main document (all of the thumbs you can actually see) finishes
   * loading, start loading thumbs from the surrounding pages.
   *
   * We don't use <link rel="prefetch"> for this:
   *  - Prefetch is broken in FF 3, see <https://bugzilla.mozilla.org/show_bug.cgi?id=442584>.
   *  - Prefetch is very slow; it uses only one connection and doesn't seem to pipeline
   *  at all.  It'll often not finish loading a page of thumbs before the user finishes
   *  scanning the previous page.  The "slow, background" design of FF's prefetching
   *  needs some knobs to tell it whether the prefetching should be slow or aggressive.
   *  - Prefetch turns itself off if you're downloading anything.  This makes sense if
   *  it's prefetching large data (if we prefetched sample images, we'd want that), but
   *  it makes no sense for downloading 300k of thumbnails.  Again, this should be
   *  tunable, eg. <link rel="prefetch" mode="active">.
   *
   * This also works in browsers other than FF.
   */
  preload_list: [],
  preload_container: null,
  preload_raw_urls: [],
  preload_started: false,
  onload_event_initialized: false,

  get_default_preload_container: function()
  {
    if(!this.preload_container)
      this.preload_container = new PreloadContainer();

    return this.preload_container;
  },
  init: function()
  {
    if(this.onload_event_initialized)
      return;

    this.onload_event_initialized = true;
    Event.observe(window, "load", function() { Preload.preload_started = true; Preload.start_preload(); } );
  },

  /* Preload the given URL once window.load has fired. */
  preload: function(url)
  {
    var container = this.get_default_preload_container();

    Preload.init();
    Preload.preload_list.push([url, container]);
    Preload.start_preload();
  },

  /* Load the given URL with an AJAX request.  This is used to load things that aren't
   * images. */
  preload_raw: function(url)
  {
    Preload.init();
    Preload.preload_raw_urls.push(url);
    Preload.start_preload();
  },

  create_raw_preload: function(url)
  {
    return new Ajax.Request(url, {
      method: "get",
      evalJSON: false,
      evalJS: false,
      parameters: null
    });
  },
  start_preload: function()
  {
    if(!Preload.preload_started)
      return;

    for(var i=0; i < Preload.preload_list.length; ++i)
    {
      var preload = Preload.preload_list[i];
      var container = preload[1];
      container.preload(preload[0]);
    }
    Preload.preload_list.length = [];

    for(var i=0; i < Preload.preload_raw_urls.length; ++i)
    {
      var url = Preload.preload_raw_urls[i];
      Preload.create_raw_preload(url);
    }
    Preload.preload_raw_urls = [];
  }
}


ReferralBanner = function(ref)
{
  /* Stop if > privileged: */
  if(User.get_current_user_level() > 30)
  {
    this.container = null;
    return;
  }

  this.container = ref;
  if(!ref)
    return;

  this.container.down(".close-button").on("click", function(e) {
    e.stop();
    this.container.removeClassName("shown");
  }.bind(this));
}

ReferralBanner.prototype.show_referral = function()
{
  if(!this.container)
    return;

  this.container.show();

  /* If we don't defer after removing display: none, the -webkit-transition won't transition
   * from the correct position. */
  (function() {
    this.container.addClassName("shown");
  }).bind(this).defer();
}


ReferralBanner.prototype.increment_view_count = function()
{
  var view_count = Cookie.get_int("viewed");
  ++view_count;

  Cookie.put("viewed", view_count);
  return view_count;
}

ReferralBanner.prototype.increment_views_and_check_referral = function()
{
  var delay_between_referral_reset = 60*60*24;
  var view_count_before_referral = 9999;

  var view_count = this.increment_view_count();

  /* sref is the last time we showed the referral.  As long as it's set, we won't show
   * it again. */
  var referral_last_shown = Cookie.get_int("sref");
  var now = new Date().getTime() / 1000;

  /* If the last time the referral was shown was a long time ago, clear everything and start over.
   * Once we clear this, vref is set and we'll start counting views from there.
   *
   * Also clear the timer if it's in the future; this can happen if the clock was adjusted. */
  if(referral_last_shown && (referral_last_shown > now || now - referral_last_shown >= delay_between_referral_reset))
  {
    Cookie.put("sref", 0);
    referral_last_shown = 0;
    Cookie.put("vref", view_count - 1);
  }

  if(referral_last_shown)
    return;

  var view_count_start = Cookie.get_int("vref");
  if(view_count >= view_count_start && view_count - view_count_start < view_count_before_referral)
    return;

  Cookie.put("sref", now);
  this.show_referral();
}



RelatedTags = {
  user_tags: [],
  recent_tags: [],
  recent_search: {},

  init: function(user_tags, artist_url) {
    this.user_tags = (user_tags.match(/\S+/g) || []).sort()
    this.recent_tags = Cookie.get("recent_tags").match(/\S+/g)
    if (this.recent_tags) {
      this.recent_tags = this.recent_tags.sort().uniq(true)
    } else {
      this.recent_tags = []
    }

    if ((artist_url != null) && (artist_url.match(/^http/))) {
      this.find_artist($F("post_source"))
    } else {
      this.build_all({})
    }
  },

  toggle: function(link, field) {
    var field = $(field)
    var tags = field.value.match(/\S+/g) || []
    var tag = (link.innerText || link.textContent).replace(/ /g, "_")

    if (tags.include(tag)) {
      field.value = tags.without(tag).join(" ") + " "
    } else {
      field.value = tags.concat([tag]).join(" ") + " "
    }

    this.build_all(this.recent_search)
    return false
  },

  build_html: function(key, tags) {
    if (tags == null || tags.size() == 0) {
      return ""
    }

    var html = ""
    var current = $F("post_tags").match(/\S+/g) || []

    html += '<div class="tag-column">'
    html += '<h6><em>' + key.replace(/_/g, " ") + '</em></h6>'
  
    for (var i=0; i<tags.size(); ++i) {
      var tag = tags[i]
      html += ('<a href="/post/index?tags=' + encodeURIComponent(tag) + '" onclick="RelatedTags.toggle(this, \'post_tags\'); return false"')
    
      if (current.include(tag)) {
        html += ' style="background: rgb(0, 111, 250); color: white;"'
      }
    
      html += '>' + tag.escapeHTML().replace(/_/g, " ") + '</a><br> '
    }
    html += '</div>'

    return html
  },

  build_all: function(tags) {
    this.recent_search = tags
  
    var html = this.build_html("My Tags", this.user_tags) + this.build_html("Recent Tags", this.recent_tags)
    var keys = []

    for (key in tags) {
      keys.push(key)
    }
  
    keys.sort()

    for (var i=0; i<keys.size(); ++i) {
      html += this.build_html(keys[i], tags[keys[i]])
    }
  
    $("related").update(html)
  },

  find: function(field, type) {
    $("related").update("<em>Fetching...</em>")
    var field = $(field)
		var tags = null
		
		if (field.selectionStart != field.textLength) {
			var a = field.selectionStart
			var b = field.selectionEnd
			
			if(a != b)
                        {
                          while ((b > 0) && field.value[b] != " ") {
                            b -= 1
                          }
                        }
			while ((a > 0) && field.value[a] != " ") {
				a -= 1
			}
			
			if (field.value[a] == " ") {
				a += 1
			}
			
			while ((b < field.textLength) && field.value[b] != " ") {
				b += 1
			}
			
			tags = field.value.slice(a, b)
		} else {
			tags = field.value
		}

    var params = {"tags": tags}
    if (type) {
      params["type"] = type
    }
  
    new Ajax.Request("/tag/related.json", {
      method: 'get',
      parameters: params,
      onComplete: function(resp) {
        var resp = resp.responseJSON
        var converted = this.convert_related_js_response(resp)
        this.build_all(converted)
      }.bind(this)
    })
  },

  convert_related_js_response: function(resp) {
    var converted = {}
  
    for (k in resp) {
      var tags = resp[k].map(function(x) {return x[0]}).sort()
      converted[k] = tags
    }

    return converted
  },

  find_artist: function(url) {
    if (url.match(/^http/)) {
      new Ajax.Request("/artist/index.json", {
        method: "get",
        parameters: {
          "url": url,
          "limit": "10"
        },
        onComplete: function(resp) {
          var resp = resp.responseJSON
          this.build_all({"Artist": resp.map(function(x) {return x.name})})
        }.bind(this)
      })
    }
  }
}


// script.aculo.us scriptaculous.js v1.8.1, Thu Jan 03 22:07:12 -0500 2008

// Copyright (c) 2005-2007 Thomas Fuchs (http://script.aculo.us, http://mir.aculo.us)
// 
// Permission is hereby granted, free of charge, to any person obtaining
// a copy of this software and associated documentation files (the
// "Software"), to deal in the Software without restriction, including
// without limitation the rights to use, copy, modify, merge, publish,
// distribute, sublicense, and/or sell copies of the Software, and to
// permit persons to whom the Software is furnished to do so, subject to
// the following conditions:
// 
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
// LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
// OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
// WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//
// For details, see the script.aculo.us web site: http://script.aculo.us/

var Scriptaculous = {
  Version: '1.8.1',
  require: function(libraryName) {
    // inserting via DOM fails in Safari 2.0, so brute force approach
    document.write('<script type="text/javascript" src="'+libraryName+'"><\/script>');
  },
  REQUIRED_PROTOTYPE: '1.6.0',
  load: function() {
    function convertVersionString(versionString){
      var r = versionString.split('.');
      return parseInt(r[0])*100000 + parseInt(r[1])*1000 + parseInt(r[2]);
    }
 
    if((typeof Prototype=='undefined') || 
       (typeof Element == 'undefined') || 
       (typeof Element.Methods=='undefined') ||
       (convertVersionString(Prototype.Version) < 
        convertVersionString(Scriptaculous.REQUIRED_PROTOTYPE)))
       throw("script.aculo.us requires the Prototype JavaScript framework >= " +
        Scriptaculous.REQUIRED_PROTOTYPE);
    
    $A(document.getElementsByTagName("script")).findAll( function(s) {
      return (s.src && s.src.match(/scriptaculous\.js(\?.*)?$/))
    }).each( function(s) {
      var path = s.src.replace(/scriptaculous\.js(\?.*)?$/,'');
      var includes = s.src.match(/\?.*load=([a-z,]*)/);
      (includes ? includes[1] : 'builder,effects,dragdrop,controls,slider,sound').split(',').each(
       function(include) { Scriptaculous.require(path+include+'.js') });
    });
  }
}

Scriptaculous.load();

/*
 * file must be a Blob object.  Create and return a thumbnail of the image.
 * Perform an image search using post/similar.
 *
 * On completion, onComplete(result) will be called, where result is an object with
 * these properties:
 *
 * success: true or false.
 *
 * On failure:
 * aborted: true if failure was due to a user abort.
 * chromeFailure: If true, the image loaded but was empty.  Chrome probably ran out
 * of memory, but the selected file may be a valid image.
 *
 * On success:
 * canvas: On success, the canvas containing the thumbnailed image.
 *
 */
ThumbnailUserImage = function(file, onComplete)
{
  /* Create the shared image pool, if we havn't yet. */
  if(ThumbnailUserImage.image_pool == null)
    ThumbnailUserImage.image_pool = new ImgPoolHandler();

  this.file = file;
  this.canvas = create_canvas_2d();
  this.image = ThumbnailUserImage.image_pool.get();
  this.onComplete = onComplete;

  this.url = URL.createObjectURL(this.file);

  this.image.on("load", this.image_load_event.bindAsEventListener(this));
  this.image.on("abort", this.image_abort_event.bindAsEventListener(this));
  this.image.on("error", this.image_error_event.bindAsEventListener(this));

  document.documentElement.addClassName("progress");

  this.image.src = this.url;
}

/* This is a shared pool; for clarity, don't put it in the prototype. */
ThumbnailUserImage.image_pool = null;

/* Cancel any running request.  The onComplete callback will not be called.
 * The object must not be reused. */
ThumbnailUserImage.prototype.destroy = function()
{
  document.documentElement.removeClassName("progress");

  this.onComplete = null;

  this.image.stopObserving();
  ThumbnailUserImage.image_pool.release(this.image);
  this.image = null;

  if(this.url != null)
  {
    URL.revokeObjectURL(this.url);
    this.url = null;
  }
}

ThumbnailUserImage.prototype.completed = function(result)
{
  if(this.onComplete)
    this.onComplete(result);
  this.destroy();
}

/* When the image finishes loading after form_submit_event sets it, update the canvas
 * thumbnail from it. */
ThumbnailUserImage.prototype.image_load_event = function(e)
{
  /* Reduce the image size to thumbnail resolution. */
  var width = this.image.width;
  var height = this.image.height;
  var max_width = 128;
  var max_height = 128;
  if(width > max_width)
  {
    var ratio = max_width/width;
    height *= ratio; width *= ratio;
  }
  if(height > max_height)
  {
    var ratio = max_height/height;
    height *= ratio; width *= ratio;
  }
  width = Math.round(width);
  height = Math.round(height);

  /* Set the canvas to the image size we want. */
  var canvas = this.canvas;
  canvas.width = width;
  canvas.height = height;

  /* Blit the image onto the canvas. */
  var ctx = canvas.getContext("2d");

  /* Clear the canvas, so check_image_contents can check that the data was correctly loaded. */
  ctx.clearRect(0, 0, canvas.width, canvas.height);

  ctx.drawImage(this.image, 0, 0, canvas.width, canvas.height);

  if(!this.check_image_contents())
  {
    this.completed({ success: false, chromeFailure: true });
    return;
  }

  this.completed({ success: true, canvas: this.canvas });
}

/*
 * Work around a Chrome bug.  When very large images fail to load, we still get
 * onload and the image acts like a loaded, completely transparent image, instead
 * of firing onerror.  This makes it difficult to tell if the image actually loaded
 * or not.  Check that the image loaded by looking at the results; reject the image
 * if it's completely transparent.
 */
ThumbnailUserImage.prototype.check_image_contents = function()
{
  var ctx = this.canvas.getContext("2d");
  var image = ctx.getImageData(0, 0, this.canvas.width, this.canvas.height);
  var data = image.data;

  /* Iterate through the alpha components, and search for any nonzero value. */
  var idx = 3;
  var max_idx = image.width * image.height * 4;
  while(idx < max_idx)
  {
    if(data[idx] != 0)
      return true;
    idx += 4;
  }
  return false;
}

ThumbnailUserImage.prototype.image_abort_event = function(e)
{
  this.completed({ success: false, aborted: true });
}

/* This happens on normal errors, usually because the file isn't a supported image. */
ThumbnailUserImage.prototype.image_error_event = function(e)
{
  this.completed({ success: false });
}

/* If the necessary APIs aren't supported, don't use ThumbnailUserImage. */
if(!("URL" in window) || create_canvas_2d() == null)
  ThumbnailUserImage = null;

SimilarWithThumbnailing = function(form)
{
  this.similar = null;
  this.form = form;
  this.force_file = null;

  form.on("submit", this.form_submit_event.bindAsEventListener(this));
}

SimilarWithThumbnailing.prototype.form_submit_event = function(e)
{
  var post_file = this.form.down("#file");

  /* If the files attribute isn't supported, or we have no file (source upload), use regular
   * form submission. */
  if(post_file.files == null || post_file.files.length == 0)
    return;

  /* If we failed to load the image last time due to a silent Chrome error, continue with
   * the submission normally this time. */
  var file = post_file.files[0];
  if(this.force_file && this.force_file == file)
  {
    this.force_file = null;
    return;
  }

  e.stop();

  if(this.similar)
    this.similar.destroy();
  this.similar = new ThumbnailUserImage(file, this.complete.bind(this));
}

/* Submit a post/similar request using the image currently in the canvas. */
SimilarWithThumbnailing.prototype.complete = function(result)
{
  if(result.chromeFailure)
  {
    notice("The image failed to load; submitting normally...");

    this.force_file = this.file;

    /* Resend the submit event.  Defer it, so the notice can take effect before we
     * navigate off the page. */
    (function() { this.form.simulate_submit(); }).bind(this).defer();
    return;
  }

  if(!result.success)
  {
    if(!result.aborted)
      alert("The file couldn't be loaded.");
    return;
  }

  /* Grab a data URL from the canvas; this is what we'll send to the server. */
  var data_url = result.canvas.toDataURL();

  /* Create the FormData containing the thumbnail image we're sending. */
  var form_data = new FormData();
  form_data.append("url", data_url);

  var req = new Ajax.Request("/post/similar.json", {
    method: "post",
    postBody: form_data,

    /* Tell Prototype not to change XHR's contentType; it breaks FormData. */
    contentType: null,

    onComplete: function(resp)
    {
      var json = resp.responseJSON;
      if(!json.success)
      {
        notice(json.reason);
        return;
      }

      /* Redirect to the search results. */
      window.location.href = "/post/similar?search_id=" + json.search_id;
    }
  });
}

/* If the necessary APIs aren't supported, don't use SimilarWithThumbnailing. */
if(!("FormData" in window) || !ThumbnailUserImage)
  SimilarWithThumbnailing = null;



// script.aculo.us slider.js v1.8.0, Tue Nov 06 15:01:40 +0300 2007

// Copyright (c) 2005-2007 Marty Haught, Thomas Fuchs 
//
// script.aculo.us is freely distributable under the terms of an MIT-style license.
// For details, see the script.aculo.us web site: http://script.aculo.us/

if (!Control) var Control = { };

// options:
//  axis: 'vertical', or 'horizontal' (default)
//
// callbacks:
//  onChange(value)
//  onSlide(value)
Control.Slider = Class.create({
  initialize: function(handle, track, options) {
    var slider = this;
    
    if (Object.isArray(handle)) {
      this.handles = handle.collect( function(e) { return $(e) });
    } else {
      this.handles = [$(handle)];
    }
    
    this.track   = $(track);
    this.options = options || { };

    this.axis      = this.options.axis || 'horizontal';
    this.increment = this.options.increment || 1;
    this.step      = parseInt(this.options.step || '1');
    this.range     = this.options.range || $R(0,1);
    
    this.value     = 0; // assure backwards compat
    this.values    = this.handles.map( function() { return 0 });
    this.spans     = this.options.spans ? this.options.spans.map(function(s){ return $(s) }) : false;
    this.options.startSpan = $(this.options.startSpan || null);
    this.options.endSpan   = $(this.options.endSpan || null);

    this.restricted = this.options.restricted || false;

    this.maximum   = this.options.maximum || this.range.end;
    this.minimum   = this.options.minimum || this.range.start;

    // Will be used to align the handle onto the track, if necessary
    this.alignX = parseInt(this.options.alignX || '0');
    this.alignY = parseInt(this.options.alignY || '0');
    
    this.trackLength = this.maximumOffset() - this.minimumOffset();

    this.handleLength = this.isVertical() ? 
      (this.handles[0].offsetHeight != 0 ? 
        this.handles[0].offsetHeight : this.handles[0].style.height.replace(/px$/,"")) : 
      (this.handles[0].offsetWidth != 0 ? this.handles[0].offsetWidth : 
        this.handles[0].style.width.replace(/px$/,""));

    this.active   = false;
    this.dragging = false;
    this.disabled = false;

    if (this.options.disabled) this.setDisabled();

    // Allowed values array
    this.allowedValues = this.options.values ? this.options.values.sortBy(Prototype.K) : false;
    if (this.allowedValues) {
      this.minimum = this.allowedValues.min();
      this.maximum = this.allowedValues.max();
    }

    this.eventMouseDown = this.startDrag.bindAsEventListener(this);
    this.eventMouseUp   = this.endDrag.bindAsEventListener(this);
    this.eventMouseMove = this.update.bindAsEventListener(this);

    // Initialize handles in reverse (make sure first handle is active)
    this.handles.each( function(h,i) {
      i = slider.handles.length-1-i;
      slider.setValue(parseFloat(
        (Object.isArray(slider.options.sliderValue) ? 
          slider.options.sliderValue[i] : slider.options.sliderValue) || 
         slider.range.start), i);
      h.makePositioned().observe("mousedown", slider.eventMouseDown);
    });
    
    this.track.observe("mousedown", this.eventMouseDown);
    document.observe("mouseup", this.eventMouseUp);
    document.observe("mousemove", this.eventMouseMove);
    
    this.initialized = true;
  },
  dispose: function() {
    var slider = this;    
    Event.stopObserving(this.track, "mousedown", this.eventMouseDown);
    Event.stopObserving(document, "mouseup", this.eventMouseUp);
    Event.stopObserving(document, "mousemove", this.eventMouseMove);
    this.handles.each( function(h) {
      Event.stopObserving(h, "mousedown", slider.eventMouseDown);
    });
  },
  setDisabled: function(){
    this.disabled = true;
  },
  setEnabled: function(){
    this.disabled = false;
  },  
  getNearestValue: function(value){
    if (this.allowedValues){
      if (value >= this.allowedValues.max()) return(this.allowedValues.max());
      if (value <= this.allowedValues.min()) return(this.allowedValues.min());
      
      var offset = Math.abs(this.allowedValues[0] - value);
      var newValue = this.allowedValues[0];
      this.allowedValues.each( function(v) {
        var currentOffset = Math.abs(v - value);
        if (currentOffset <= offset){
          newValue = v;
          offset = currentOffset;
        } 
      });
      return newValue;
    }
    if (value > this.range.end) return this.range.end;
    if (value < this.range.start) return this.range.start;
    return value;
  },
  setValue: function(sliderValue, handleIdx){
    if (!this.active) {
      this.activeHandleIdx = handleIdx || 0;
      this.activeHandle    = this.handles[this.activeHandleIdx];
      this.updateStyles();
    }
    handleIdx = handleIdx || this.activeHandleIdx || 0;
    if (this.initialized && this.restricted) {
      if ((handleIdx>0) && (sliderValue<this.values[handleIdx-1]))
        sliderValue = this.values[handleIdx-1];
      if ((handleIdx < (this.handles.length-1)) && (sliderValue>this.values[handleIdx+1]))
        sliderValue = this.values[handleIdx+1];
    }
    sliderValue = this.getNearestValue(sliderValue);
    this.values[handleIdx] = sliderValue;
    this.value = this.values[0]; // assure backwards compat
    
    this.handles[handleIdx].style[this.isVertical() ? 'top' : 'left'] = 
      this.translateToPx(sliderValue);
    
    this.drawSpans();
    if (!this.dragging || !this.event) this.updateFinished();
  },
  setValueBy: function(delta, handleIdx) {
    this.setValue(this.values[handleIdx || this.activeHandleIdx || 0] + delta, 
      handleIdx || this.activeHandleIdx || 0);
  },
  translateToPx: function(value) {
    return Math.round(
      ((this.trackLength-this.handleLength)/(this.range.end-this.range.start)) * 
      (value - this.range.start)) + "px";
  },
  translateToValue: function(offset) {
    return ((offset/(this.trackLength-this.handleLength) * 
      (this.range.end-this.range.start)) + this.range.start);
  },
  getRange: function(range) {
    var v = this.values.sortBy(Prototype.K); 
    range = range || 0;
    return $R(v[range],v[range+1]);
  },
  minimumOffset: function(){
    return(this.isVertical() ? this.alignY : this.alignX);
  },
  maximumOffset: function(){
    return(this.isVertical() ? 
      (this.track.offsetHeight != 0 ? this.track.offsetHeight :
        this.track.style.height.replace(/px$/,"")) - this.alignY : 
      (this.track.offsetWidth != 0 ? this.track.offsetWidth : 
        this.track.style.width.replace(/px$/,"")) - this.alignX);
  },  
  isVertical:  function(){
    return (this.axis == 'vertical');
  },
  drawSpans: function() {
    var slider = this;
    if (this.spans)
      $R(0, this.spans.length-1).each(function(r) { slider.setSpan(slider.spans[r], slider.getRange(r)) });
    if (this.options.startSpan)
      this.setSpan(this.options.startSpan,
        $R(0, this.values.length>1 ? this.getRange(0).min() : this.value ));
    if (this.options.endSpan)
      this.setSpan(this.options.endSpan, 
        $R(this.values.length>1 ? this.getRange(this.spans.length-1).max() : this.value, this.maximum));
  },
  setSpan: function(span, range) {
    if (this.isVertical()) {
      span.style.top = this.translateToPx(range.start);
      span.style.height = this.translateToPx(range.end - range.start + this.range.start);
    } else {
      span.style.left = this.translateToPx(range.start);
      span.style.width = this.translateToPx(range.end - range.start + this.range.start);
    }
  },
  updateStyles: function() {
    this.handles.each( function(h){ Element.removeClassName(h, 'selected') });
    Element.addClassName(this.activeHandle, 'selected');
  },
  startDrag: function(event) {
    if (Event.isLeftClick(event)) {
      if (!this.disabled){
        this.active = true;
        
        var handle = Event.element(event);
        var pointer  = [Event.pointerX(event), Event.pointerY(event)];
        var track = handle;
        if (track==this.track) {
          var offsets  = Position.cumulativeOffset(this.track); 
          this.event = event;
          this.setValue(this.translateToValue( 
           (this.isVertical() ? pointer[1]-offsets[1] : pointer[0]-offsets[0])-(this.handleLength/2)
          ));
          var offsets  = Position.cumulativeOffset(this.activeHandle);
          this.offsetX = (pointer[0] - offsets[0]);
          this.offsetY = (pointer[1] - offsets[1]);
        } else {
          // find the handle (prevents issues with Safari)
          while((this.handles.indexOf(handle) == -1) && handle.parentNode) 
            handle = handle.parentNode;
            
          if (this.handles.indexOf(handle)!=-1) {
            this.activeHandle    = handle;
            this.activeHandleIdx = this.handles.indexOf(this.activeHandle);
            this.updateStyles();
            
            var offsets  = Position.cumulativeOffset(this.activeHandle);
            this.offsetX = (pointer[0] - offsets[0]);
            this.offsetY = (pointer[1] - offsets[1]);
          }
        }
      }
      Event.stop(event);
    }
  },
  update: function(event) {
   if (this.active) {
      if (!this.dragging) this.dragging = true;
      this.draw(event);
      if (Prototype.Browser.WebKit) window.scrollBy(0,0);
      Event.stop(event);
   }
  },
  draw: function(event) {
    var pointer = [Event.pointerX(event), Event.pointerY(event)];
    var offsets = Position.cumulativeOffset(this.track);
    pointer[0] -= this.offsetX + offsets[0];
    pointer[1] -= this.offsetY + offsets[1];
    this.event = event;
    this.setValue(this.translateToValue( this.isVertical() ? pointer[1] : pointer[0] ));
    if (this.initialized && this.options.onSlide)
      this.options.onSlide(this.values.length>1 ? this.values : this.value, this);
  },
  endDrag: function(event) {
    if (this.active && this.dragging) {
      this.finishDrag(event, true);
      Event.stop(event);
    }
    this.active = false;
    this.dragging = false;
  },  
  finishDrag: function(event, success) {
    this.active = false;
    this.dragging = false;
    this.updateFinished();
  },
  updateFinished: function() {
    if (this.initialized && this.options.onChange) 
      this.options.onChange(this.values.length>1 ? this.values : this.value, this);
    this.event = null;
  }
});


// script.aculo.us sound.js v1.8.0, Tue Nov 06 15:01:40 +0300 2007

// Copyright (c) 2005-2007 Thomas Fuchs (http://script.aculo.us, http://mir.aculo.us)
//
// Based on code created by Jules Gravinese (http://www.webveteran.com/)
//
// script.aculo.us is freely distributable under the terms of an MIT-style license.
// For details, see the script.aculo.us web site: http://script.aculo.us/

Sound = {
  tracks: {},
  _enabled: true,
  template:
    new Template('<embed style="height:0" id="sound_#{track}_#{id}" src="#{url}" loop="false" autostart="true" hidden="true"/>'),
  enable: function(){
    Sound._enabled = true;
  },
  disable: function(){
    Sound._enabled = false;
  },
  play: function(url){
    if(!Sound._enabled) return;
    var options = Object.extend({
      track: 'global', url: url, replace: false
    }, arguments[1] || {});
    
    if(options.replace && this.tracks[options.track]) {
      $R(0, this.tracks[options.track].id).each(function(id){
        var sound = $('sound_'+options.track+'_'+id);
        sound.Stop && sound.Stop();
        sound.remove();
      })
      this.tracks[options.track] = null;
    }
      
    if(!this.tracks[options.track])
      this.tracks[options.track] = { id: 0 }
    else
      this.tracks[options.track].id++;
      
    options.id = this.tracks[options.track].id;
    $$('body')[0].insert( 
      Prototype.Browser.IE ? new Element('bgsound',{
        id: 'sound_'+options.track+'_'+options.id,
        src: options.url, loop: 1, autostart: true
      }) : Sound.template.evaluate(options));
  }
};

if(Prototype.Browser.Gecko && navigator.userAgent.indexOf("Win") > 0){
  if(navigator.plugins && $A(navigator.plugins).detect(function(p){ return p.name.indexOf('QuickTime') != -1 }))
    Sound.template = new Template('<object id="sound_#{track}_#{id}" width="0" height="0" type="audio/mpeg" data="#{url}"/>')
  else
    Sound.play = function(){}
}


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
  var current_version = 5;
  if(localStorage.tag_data_format != current_version)
  {
    delete localStorage.tag_data;
    delete localStorage.tag_data_version;
    delete localStorage.recent_tags;
    localStorage.tag_data_format = current_version;
  }

  /* Pull in recent tags.  This is entirely local data and not too big, so always load it. */
  this.recent_tags = localStorage.recent_tags || "";

  this.load_data_complete_callbacks = [];

  this.rapid_backspaces_received = 0;
  this.updates_deferred = false;
}

TagCompletionClass.prototype.init = function(current_version)
{
  if(this.loaded)
    return;
  this.most_recent_tag_data_version = current_version;
}

/*
 * If cached data is available, load it.  If the cached data is out of date, run an
 * update asynchronously.  Return true if data is available and tag completions may
 * be done, whether or not the data is current.  Call onComplete when up-to-date tag
 * data is available; if the current cached data is known to be current, it will be
 * called before this function returns.
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
    return this.tag_data != null;
  }

  /* Add the callback to the list. */
  if(onComplete)
    this.load_data_complete_callbacks.push(onComplete);

  /* If we're already loading, let the existing request finish; it'll run the callback. */
  if(this.loading)
    return this.tag_data != null;
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

  /* If we have data available, load it. */
  if(localStorage.tag_data != null)
    this.tag_data = localStorage.tag_data;

  /* If we've been told the current tag data revision and we're already on it, or if we havn't
   * been told the revision at all, use the data we have. */
  if(localStorage.tag_data != null)
  {
    if(this.most_recent_tag_data_version == null || localStorage.tag_data_version == this.most_recent_tag_data_version)
    {
      // console.log("Already on most recent tag data version");
      complete();
      return this.tag_data != null;
    }
  }
  
  /* Request the tag data from the server.  Tell the server the data version we already
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

  return this.tag_data != null;
}

/* When form is submitted, call add_recent_tags_from_update for the given tags and old_tags
 * fields. */
TagCompletionClass.prototype.observe_tag_changes_on_submit = function(form, tags_field, old_tags_field)
{
  return form.on("submit", function(e) {
    var old_tags = old_tags_field? old_tags_field.value:null;
    TagCompletion.add_recent_tags_from_update(tags_field.value, old_tags);
  });
}

/* From a tag string, eg. "1`tagme`alias`alias2`", retrieve the tag name "tagme". */
var get_tag_from_string = function(tag_string)
{
  var m = tag_string.match(/\d+`([^`]*)`.*/);
  if(!m)
    throw "Unparsable cached tag: '" + tag_string + "'";
  return m[1];
}

/*
 * Like string.split, but rather than each item of data being separated by the separator,
 * each item of data ends in the separator; that is, the final item is followed by the
 * separator.
 *
 * "a b c " -> ["a", "b", "c"].
 *
 * If the final item doesn't end in the separator, throw an exception.
 *
 */
var split_data = function(str, separator)
{
  var result = str.split(separator);
  if(result.length != 0)
  {
    if(result[result.length-1] != "")
      throw "String doesn't end in separator";
    result.pop();
  }

  return result;
}

var join_data = function(items, separator)
{
  if(items.length == 0)
    return "";
  return items.join(separator) + separator;
}

/* Update the cached types of all known tags in tag_data and recent_tags. */
TagCompletionClass.prototype.update_tag_types_for_list = function(tags, allow_add)
{
  var tag_map = {};

  /* Make a mapping of tags to indexes. */
  var split_tags = split_data(tags, " ");
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
        var tag_string = tag_type_idx + "`" + tag + "`";
        split_tags.push(tag_string);
      }
    }
    else
    {
      /* This is a known tag; this is the usual case.  Parse out the complete tag from the
       * original string, and update the tag type index. */
      var tag_idx = tag_map[tag];
      var existing_tag = split_tags[tag_idx];

      var m = existing_tag.match(/\d+(`.*)/);
      var new_tag_string = tag_type_idx + m[1];

      split_tags[tag_idx] = new_tag_string;
    }
  });

  return join_data(split_tags, " ");
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
  var s = "(([^`]*_)?";
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
    s += "(" + first + "[^`]*_" + last + ")";
    s += "|";
    s += "(" + last + "[^`]*_" + first + ")";
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
      s += '[^`]*';
    });
    s += ")";
    regex_parts.push(s);
  }

  /* The space is included in the result, so the result tags can be matched with the
   * same regexes, for in reorder_search_results. 
   *
   * (\d)+  match the alias ID                      1`
   * [^ ]*: start at the beginning of any alias     1`foo`bar`
   * ... match ...
   * [^`]*` all matches are prefix matches          1`foo`bar`tagme`
   * [^ ]*  match any remaining aliases             1`foo`bar`tagme`tag_me`
   */
  var regex_string = regex_parts.join("|");
  regex_string = "(\\d+)[^ ]*`(" + regex_string + ")[^`]*`[^ ]* ";

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
  if(tag.indexOf(" ") != -1 || tag.indexOf("`") != -1)
    throw "Invalid recent tag: " + tag;

  this.remove_recent_tag(tag);

  /* Look up the tag type if we know it. */
  var tag_type = Post.tag_types.get(tag) || "general";
  var tag_type_idx = Post.tag_type_names.indexOf(tag_type);

  /* We should know all tag types. */
  if(tag_type_idx == -1)
    throw "Unknown tag type: " + tag_type;

  /* Add the tag to the front.  Always append a space, not just between entries. */
  var tag_entry = tag_type_idx + "`" + tag + "` ";
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

/* Remove the tag from the recent tag list. */
TagCompletionClass.prototype.remove_recent_tag = function(tag)
{
  var escaped_tag = RegExp.escape(tag);
  var re = new RegExp("\\d`" + escaped_tag + "` ", "g");
  this.recent_tags = this.recent_tags.replace(re, "");
  localStorage.recent_tags = this.recent_tags;
}

/* Add as recent tags all tags which are in tags and not in old_tags.  If this is from an
 * edit form, old_tags must be the hidden old_tags value in the edit form; if this is
 * from a search form, old_tags must be null. */
TagCompletionClass.prototype.add_recent_tags_from_update = function(tags, old_tags)
{
  tags = tags.split(" ");
  if(old_tags != null)
    old_tags = old_tags.split(" ");

  tags.each(function(tag) {
    /* Ignore invalid tags. */
    if(tag.indexOf("`") != -1)
      return;
    /* Ignore rating shortcuts. */
    if("sqe".indexOf(tag) != -1)
      return;
    /* Ignore tags that the user didn't just add. */
    if(old_tags && old_tags.indexOf(tag) != -1)
      return;

    /*
     * We may be adding tags from an edit form or a search form.  If we're on an edit
     * form, old_tags is set; if we're on a search form, old_tags is null.
     *
     * If we're on a search form, ignore non-metatags that don't exist in tag_data.  This
     * will just allow adding typos to recent tag data.
     *
     * If we're on an edit form, allow these completely new tags to be added, since the
     * edit form is going to create them.
     */
    if(old_tags == null && tag.indexOf(":") == -1)
    {
      if(this.tag_data.indexOf("`" + tag + "`") == -1)
        return;
    }

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
 *
 * [["tag1", "tag2", "tag3"], 1]
 *
 * The value 1 is the number of results from the beginning which come from recent_tags,
 * rather than tag_data.
 */
TagCompletionClass.prototype.complete_tag = function(tag, options)
{
  if(this.tag_data == null)
    throw "Tag data isn't loaded";

  if(options == null)
    options = {};

  if(tag == "")
    return [[], 0];

  /* Make a list of all results; this will be ordered recent tags first, other tags
   * sorted by tag count.  Request more results than we need, since we'll reorder
   * them below before cutting it off. */
  var re = this.create_tag_search_regex(tag, { global: true });
  var recent_results = this.retrieve_tag_search(re, this.recent_tags, {max_results: 100});
  var main_results = this.retrieve_tag_search(re, this.tag_data, {max_results: 100});

  recent_results = this.reorder_search_results(tag, recent_results);
  main_results = this.reorder_search_results(tag, main_results);

  var recent_result_count = recent_results.length;
  var results = recent_results.concat(main_results);

  /* Hack: if the search is one of the ratings shortcuts, put that at the top, even though
   * it's not a real tag. */
  if("sqe".indexOf(tag) != -1)
    results.unshift("0`" + tag + "` ");

  results = results.slice(0, options.max_results != null? options.max_results:10);
  recent_result_count = Math.min(results.length, recent_result_count);

  /* Strip the "1`" tag type prefix off of each result. */
  var final_results = [];
  var tag_types = {};
  var final_aliases = [];
  results.each(function(tag) {
    var m = tag.match(/(\d+)`([^`]*)`(([^ ]*)`)? /);
    if(!m)
    {
      ReportError("Unparsable cached tag: '" + tag + "'", null, null, null, null);
      throw "Unparsable cached tag: '" + tag + "'";
    }

    var tag = m[2];
    var tag_type = Post.tag_type_names[m[1]];
    var aliases = m[4];
    if(m[4])
      aliases = aliases.split("`");
    else
      aliases = [];
    tag_types[tag] = tag_type;

    if(final_results.indexOf(tag) == -1)
    {
      final_results.push(tag);
      final_aliases.push(aliases);
    }
  });

  /* Register tag types of results with Post. */
  Post.register_tags(tag_types, true);

  return [final_results, recent_result_count, final_aliases];
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

  this.hide();
}

TagCompletionBox.prototype.input_mouse = function(event)
{
  this.update.defer();
}

TagCompletionBox.prototype.input_keydown = function(event)
{
  if(event.target != this.input_field)
    return;

  /* Handle backspaces even when hidden. */
  if(event.keyCode == Event.KEY_BACKSPACE)
  {
    /*
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

    if(this.backspace_timeout)
      clearTimeout(this.backspace_timeout);
    this.backspace_timeout = setTimeout(function() {
      this.rapid_backspaces_received = 0;
    }.bind(this), 100);

    if(this.rapid_backspaces_received > 1)
    {
      this.updates_deferred = true;
      if(this.defer_timeout != null)
        clearTimeout(this.defer_timeout);
      this.defer_timeout = setTimeout(function() {
        this.updates_deferred = false;
        this.update();
      }.bind(this), 100);
    }
  }

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
  if(event.target.hasClassName("remove-recent-tag"))
  {
    TagCompletion.remove_recent_tag(element.result_tag);
    this.update(true);
    return;
  }
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

TagCompletionBox.prototype.update = function(force)
{
  if(this.updates_deferred && !force)
    return;

  /* If the tag data hasn't been loaded, run the load and rerun the update when it
   * completes. */
  if(TagCompletion.tag_data == null)
  {
    /* If this returns true, we'll display with the data we have now.  If this happens,
     * don't update during the callback; it's bad UI to be changing the list out from
     * under the user at a seemingly random time. */
    var data_available = TagCompletion.load_data(function() {
      if(data_available)
        return;

      /* After the load completes, force an update, even though the tag we're completing
       * hasn't changed; the tag data may have. */
      this.current_tag = null;
      this.update();
    }.bind(this));

    if(!data_available)
      return;
  }

  /* Figure out the tag the cursor is on. */
  var offset = this.get_input_word_offset(this.input_field);
  var tag = this.input_field.value.substr(offset.start, offset.end-offset.start);

  if(tag == this.current_tag && !force)
    return;

  this.hide();

  /* Don't show the autocomplete unless the contents actually change, so we can still
   * navigate multiline tag input boxes with the arrow keys. */
  if(this.last_value == this.input_field.value && !force)
    return;
  this.last_value = this.input_field.value;

  this.current_tag = tag;

  /* Don't display if the input field itself is hidden. */
  if(!this.input_field.recursivelyVisible())
    return;

  var tags_and_recent_count = TagCompletion.complete_tag(tag);
  var tags = tags_and_recent_count[0];
  var tag_aliases = tags_and_recent_count[2];
  var recent_result_count = tags_and_recent_count[1];
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

  for(var i = 0; i < tags.length; ++i)
  {
    var tag = tags[i];

    var li = document.createElement("LI");
    li.className = "completed-tag";
    li.setTextContent(tag);
    ul.appendChild(li);

    /* If we have any aliases, show the first one. */
    var aliases = tag_aliases[i];
    if(aliases.length > 0)
    {
      var span = document.createElement("span");
      span.className = "completed-tag-alias";
      span.setTextContent(aliases[0]);
      li.appendChild(span);
    }

    var tag_type = Post.tag_types.get(tag);
    li.className += " tag-type-" + tag_type;
    if(i < recent_result_count)
    {
      li.className += " recent-tag";

      var h = "<a class='remove-recent-tag' href='#'>X</a>'";
      li.appendChild(h.createElement());
    }
    li.result_tag = tag;
  }

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



/*
 * This file implements several helpers for fixing up full-page web apps on touchscreen
 * browsers:
 *
 * AndroidDetectWindowSize
 * EmulateDoubleClick
 * ResponsiveSingleClick
 * PreventDragScrolling
 *
 * Most of these are annoying hacks to work around the fact that WebKit on browsers was
 * designed with displaying scrolling webpages in mind, apparently without consideration
 * for full-screen applications: pages that should fill the screen at all times.  Most
 * of the browser mobile hacks no longer make sense: separate display viewports, touch
 * dragging, double-click zooming and their associated side-effects.
 */


/*
 * AndroidDetectWindowSize
 *
 * Implementing a full-page web app for Android is hard, because if you set the page to
 * "width: 100%; height: 100%;" it'll eat a big chunk of the screen with the address bar
 * which can't be scrolled off in that configuration.  We have to play games to figure out
 * the real size of the window, and set the body size to it explicitly.  This handler does
 * the following:
 *
 * - capture resize events
 * - cancel the resize event; we'll fire it again when we're done
 * - enable a large padding div, to ensure that we can scroll the window downward
 * - window.scrollTo(0, 99999999) to scroll the address bar off screen, which increases the window
 *   size to the maximum.  We use a big value here, because Android has a broken scrollTo, which
 *   animates to the specified position.  If we say (0, 1), then it'll take a while to scroll
 *   there; by giving it a huge value, it'll scroll past the scrollbar in one frame.
 * - wait a little while.  We need to wait for one frame of scrollTo's animation, but we don't
 *   know how long that'll be, so we need to poll with a timer periodically, checking
 *   document.body.scrollTop.
 * - set the body to the size of the window
 * - hide the padding div
 * - synthesize a new resize event to continue other event handlers that we originally cancelled
 *
 * resize will always be fired at least once as a result of constructing this class.
 *
 * This is only used on Android.
 */

function AndroidDetectWindowSize()
{
  $("sizing-body").setStyle({overflow: "hidden"});

  /* This is shown to make sure we can scroll the address bar off.  It goes outside
   * of #sizing-body, so it's not clipped.  By not changing #sizing-body itself, we
   * avoid reflowing the entire document more than once, when we finish. */
  this.padding = document.createElement("DIV");
  this.padding.setStyle({width: "1px", height: "5000px"});
  this.padding.style.visibility = "hidden";
  this.padding.hide();
  document.documentElement.appendChild(this.padding);

  this.window_size = [0, 0];
  this.finish = this.finish.bind(this);
  this.event_onresize = this.event_onresize.bindAsEventListener(this);

  this.finish_timer = null;
  this.last_window_orientation = window.orientation;

  window.addEventListener("resize", this.event_onresize, true);

  this.active = false;

  /* Kick off a detection cycle.  On Android 2.1, we can't do this immediately after onload; for
   * some reason this triggers some very strange browser bug where the screen will jitter up and
   * down, as if our scrollTo is competing against the browser trying to scroll somewhere.  For
   * older browsers, delay before starting.  This is no longer needed on Android 2.2. */
  var delay_seconds = 0;
  var m = navigator.userAgent.match(/Android (\d+\.\d+)/);
  if(m && parseFloat(m[1]) < 2.2)
  {
    debug("Delaying bootstrapping due to Android version " + m[1]);
    delay_seconds = 1;
  }

  /* When this detection cycle completes, a resize event will be fired so listeners can
   * act on the detected window size. */
  this.begin.bind(this).delay(delay_seconds);
}

/* Return true if Android resize handling is needed. */
AndroidDetectWindowSize.required = function()
{
  // XXX: be more specific
  return navigator.userAgent.indexOf("Android") != -1;
}

/* After we set the window size, dispatch a resize event so other listeners will notice
 * it. */
AndroidDetectWindowSize.prototype.dispatch_resize_event = function()
{
  debug("dispatch final resize event");
  var e = document.createEvent("Event");
  e.initEvent("resize", true, true);
  document.documentElement.dispatchEvent(e);
}

AndroidDetectWindowSize.prototype.begin = function()
{
  if(this.active)
    return;

  var initial_window_size = this.current_window_size();
  if(this.window_size && initial_window_size[0] == this.window_size[0] && initial_window_size[1] == this.window_size[1])
  {
    debug("skipped window size detection");
    return;
  }

  debug("begin window size detection, " + initial_window_size[0] + "x" + initial_window_size[1] + " at start (scroll pos " + document.documentElement.scrollHeight + ")");
  this.active = true;
  this.padding.show();

  /* If we set a sizing-body the last time, remove it before running again. */
  $("sizing-body").setStyle({width: "0px", height: "0px"});

  window.scrollTo(0, 99999999);
  this.finish_timer = window.setTimeout(this.finish, 0);
}

AndroidDetectWindowSize.prototype.end = function()
{
  if(!this.active)
    return;
  this.active = false;

  if(this.begin_timer != null)
    window.clearTimeout(this.begin_timer);
  this.begin_timer = null;

  if(this.finish_timer != null)
    window.clearTimeout(this.finish_timer);
  this.finish_timer = null;

  this.padding.hide();
}

AndroidDetectWindowSize.prototype.current_window_size = function()
{
  var size = [window.innerWidth, window.innerHeight];

  // We need to fudge the height up a pixel, or in many cases we'll end up with a white line
  // at the bottom of the screen (or the top in 2.3).  This seems to be sub-pixel rounding
  // error.
  ++size[1];

  return size;
}

AndroidDetectWindowSize.prototype.finish = function()
{
  if(!this.active)
    return;
  debug("window size detection: finish(), at " + document.body.scrollTop);

  /* scrollTo is supposed to be synchronous.  Android's animates.  Worse, the time it'll
   * update the animation is nondeterministic; it might happen as soon as we return from
   * calling scrollTo, or it might take a while.  Check whether we've scrolled down; if
   * we're still at the top, keep waiting. */
  if(document.body.scrollTop == 0)
  {
    console.log("Waiting for scroll...");
    this.finish_timer = window.setTimeout(this.finish, 10);
    return;
  }

  /* The scroll may still be trying to run. */
  window.scrollTo(document.body.scrollLeft, document.body.scrollTop);
  this.end();

  this.window_size = this.current_window_size();

  debug("new window size: " + this.window_size[0] + "x" + this.window_size[1]);
  $("sizing-body").setStyle({width: this.window_size[0] + "px", height: (this.window_size[1]) + "px"});

  this.dispatch_resize_event();
}

AndroidDetectWindowSize.prototype.event_onresize = function(e)
{
  if(this.last_window_orientation != window.orientation)
  {
    e.stop();

    this.last_window_orientation = window.orientation;
    if(this.active)
    {
      /* The orientation changed while we were in the middle of detecting the resolution.
       * Start over. */
      debug("Orientation changed while already detecting window size; restarting");
      this.end();
    }
    else
    {
      debug("Resize received with an orientation change; beginning");
    }

    this.begin();
    return;
  }

  if(this.active)
  {
    /* Suppress resize events while we're active, since many of them will fire.
     * Once we finish, we'll fire a single one. */
    debug("stopping resize event while we're active");
    e.stop();
    return;
  }
}


/*
 * Work around a bug on many touchscreen browsers: even when the page isn't
 * zoomable, dblclick is never fired.  We have to emulate it.
 *
 * This isn't an exact emulation of the event behavior:
 *
 * - It triggers from touchstart rather than mousedown.  The second mousedown
 *   of a double click isn't being fired reliably in Android's WebKit.
 *
 * - preventDefault on the triggering event should prevent a dblclick, but
 *   we can't find out if it's been called; there's nothing like Firefox's
 *   getPreventDefault.  We could mostly emulate this by overriding
 *   Event.preventDefault to set a flag that we can read.
 *
 * - The conditions for a double click won't match the ones of the platform.
 *
 * This is needed on Android and iPhone's WebKit.
 *
 * Note that this triggers a minor bug on Android: after firing a dblclick event,
 * we no longer receive mousemove events until the touch is released, which means
 * PreventDragScrolling can't cancel dragging.
 */

function EmulateDoubleClick()
{
  this.touchstart_event = this.touchstart_event.bindAsEventListener(this);
  this.touchend_event = this.touchend_event.bindAsEventListener(this);
  this.last_click = null;

  window.addEventListener("touchstart", this.touchstart_event, false);
  window.addEventListener("touchend", this.touchend_event, false);
}

EmulateDoubleClick.prototype.touchstart_event = function(event)
{
  var this_touch = event.changedTouches[0];
  var last_click = this.last_click;

  /* Don't store event.changedTouches or any of its contents.  Some browsers modify these
   * objects in-place between events instead of properly returning unique events. */
  var this_click = {
    timeStamp: event.timeStamp,
    target: event.target,
    identifier: this_touch.identifier,
    position: [this_touch.screenX, this_touch.screenY],
    clientPosition: [this_touch.clientX, this_touch.clientY]
  }
  this.last_click = this_click;

  if(last_click == null)
      return;

  /* If the first tap was never released then this is a multitouch double-tap.
   * Clear the original tap and don't fire anything. */
  if(event.touches.length > 1)
    return;

  /* Check that not too much time has passed. */
  var time_since_previous = event.timeStamp - last_click.timeStamp;
  if(time_since_previous > 500)
    return;

  /* Check that the clicks aren't too far apart. */
  var distance = Math.pow(this_touch.screenX - last_click.position[0], 2) + Math.pow(this_touch.screenY - last_click.position[1], 2);
  if(distance > 500)
    return;

  if(event.target != last_click.target)
    return;

  /* Synthesize a dblclick event.  Use the coordinates of the first click as the location
   * and not the second click, since if the position matters the user's first click of
   * a double-click is probably more precise than the second. */
  var e = document.createEvent("MouseEvent");
  e.initMouseEvent("dblclick", true, true, window, 
                     2,
                     last_click.position[0], last_click.position[1],
                     last_click.clientPosition[0], last_click.clientPosition[1],
                     false, false,
                     false, false,
                     0, null);

  this.last_click = null;
  event.target.dispatchEvent(e);
}

EmulateDoubleClick.prototype.touchend_event = function(event)
{
  if(this.last_click == null)
    return;

  var last_click_identifier = this.last_click.identifier;
  if(last_click_identifier == null)
    return;

  var last_click_position = this.last_click.position;
  var this_click = event.changedTouches[0];
  if(this_click.identifier == last_click_identifier)
  {
    /* If the touch moved too far when it was removed, don't fire a doubleclick; for
     * example, two quick swipe gestures aren't a double-click. */
    var distance = Math.pow(this_click.screenX - last_click_position[0], 2) + Math.pow(this_click.screenY - last_click_position[1], 2);
    if(distance > 500)
    {
      this.last_click = null;
      return;
    }
  }
}

/* 
 * Mobile WebKit has serious problems with the click event: it delays them for the
 * entire double-click timeout, and if a double-click happens it doesn't deliver the
 * click at all.  This makes clicks unresponsive, and it has this behavior even
 * when the page can't be zoomed, which means nothing happens at all.
 *
 * Generate click events from touchend events to bypass this mess.
 */
ResponsiveSingleClick = function()
{
  this.click_event = this.click_event.bindAsEventListener(this);
  this.touchstart_event = this.touchstart_event.bindAsEventListener(this);
  this.touchend_event = this.touchend_event.bindAsEventListener(this);

  this.last_touch = null;

  window.addEventListener("touchstart", this.touchstart_event, false);
  window.addEventListener("touchend", this.touchend_event, false);

  /* This is a capturing listener, so we can intercept clicks before they're
   * delivered to anyone. */
  window.addEventListener("click", this.click_event, true);
}

ResponsiveSingleClick.prototype.touchstart_event = function(event)
{
  /* If we get a touch while we already have a touch, it's multitouch, which is never
   * a click, so cancel the click. */
  if(this.last_touch != null)
  {
    debug("Cancelling click (multitouch)");
    this.last_touch = null;
    return;
  }

  /* Watch out: in older versions of WebKit, the event.touches array and the items inside
   * it are actually modified in-place when the user drags.  That means that we can't just
   * save the entire array for comparing in touchend. */
  var touch = event.changedTouches[0];
  this.last_touch = [touch.screenX, touch.screenY];
}

ResponsiveSingleClick.prototype.touchend_event = function(event)
{
  var last_touch = this.last_touch;
  if(last_touch == null)
    return;
  this.last_touch = null;

  var touch = event.changedTouches[0];
  var this_touch = [touch.screenX, touch.screenY];

  /* Don't trigger a click if the point has moved too far. */
  var distance = distance_squared(this_touch[0], this_touch[1], last_touch[0], last_touch[1]);
  if(distance > 50)
    return;

  var e = document.createEvent("MouseEvent");
  e.initMouseEvent("click", true, true, window, 
                     1,
                     touch.screenX, touch.screenY,
                     touch.clientX, touch.clientY, 
                     false, false,
                     false, false,
                     0, /* touch clicks are always button 0 - maybe not for multitouch */
                     null);
  e.synthesized_click = true;

  /* If we dispatch the click immediately, EmulateDoubleClick won't receive a
   * touchstart for the next click.  Defer dispatching it until we return. */
  (function() { event.target.dispatchEvent(e); }).defer();
}

/* Capture and cancel all clicks except the ones we generate. */
ResponsiveSingleClick.prototype.click_event = function(event)
{
  if(!event.synthesized_click)
    event.stop();
}

/* Stop all touchmove events on the document, to prevent dragging the window around. */
PreventDragScrolling = function()
{
  Element.observe(document, "touchmove", function(event) {
    event.preventDefault();
  });
}


/*
 * Save the URL hash to local DOM storage when it changes.  When called, restores the
 * previously saved hash.
 *
 * This is used on the iPhone only, and only when operating in web app mode (window.standalone).
 * The iPhone doesn't update the URL hash saved in the web app shortcut, nor does it
 * remember the current URL when using make-believe multitasking, which means every time
 * you switch out and back in you end up back to wherever you were when you first created
 * the web app shortcut.  Saving the URL hash allows switching out and back in without losing
 * your place.
 *
 * This should only be used in environments where it's been tested and makes sense.  If used
 * in a browser, or in a web app environment that properly tracks the URL hash, this will
 * just interfere with normal operation.
 */
var MaintainUrlHash = function()
{
  /* This requires DOM storage. */
  if(LocalStorageDisabled())
    return;

  /* When any part of the URL hash changes, save it. */
  var update_stored_hash = function(changed_hash_keys, old_hash, new_hash)
  {
    var hash = localStorage.current_hash = UrlHash.get_raw_hash();
  }
  UrlHash.observe(null, update_stored_hash);

  /* Restore the previous hash, if any. */
  var hash = localStorage.getItem("current_hash");
  if(hash)
    UrlHash.set_raw_hash(hash);
}

/*
 * In some versions of the browser, iPhones don't send resize events after an
 * orientation change, so we need to fire it ourself.  Try not to do this if not
 * needed, so we don't fire spurious events.
 *
 * This is never needed in web app mode.
 *
 * Needed on user-agents:
 * iPhone OS 4_0_2 ... AppleWebKit/532.9 ... Version/4.0.5
 * iPhone OS 4_1 ... AppleWebKit/532.9 ... Version/4.0.5
 *
 * Not needed on:
 * (iPad, OS 3.2)
 * CPU OS 3_2 ... AppleWebKit/531.1.10 ... Version/4.0.4 
 * iPhone OS 4_2 ... AppleWebKit/533.17.9 ... Version/5.0.2
 *
 * This seems to be specific to Version/4.0.5.
 */
var SendMissingResizeEvents = function()
{
  if(window.navigator.standalone)
    return;
  if(navigator.userAgent.indexOf("Version/4.0.5") == -1)
    return;

  var last_seen_orientation = window.orientation;
  window.addEventListener("orientationchange", function(e) {
    if(last_seen_orientation == window.orientation)
      return;
    last_seen_orientation = window.orientation;

    debug("dispatch fake resize event");
    var e = document.createEvent("Event");
    e.initEvent("resize", true, true);
    document.documentElement.dispatchEvent(e);
  }, true);
}

var InitializeFullScreenBrowserHandlers = function()
{
  /* These handlers deal with heavily browser-specific issues.  Only install them
   * on browsers that have been tested to need them. */
  if(navigator.userAgent.indexOf("Android") != -1 && navigator.userAgent.indexOf("WebKit") != -1)
  {
    new ResponsiveSingleClick();
    new EmulateDoubleClick();
  }
  else if((navigator.userAgent.indexOf("iPhone") != -1 || navigator.userAgent.indexOf("iPad") != -1 || navigator.userAgent.indexOf("iPod") != -1)
      && navigator.userAgent.indexOf("WebKit") != -1)
  {
    new ResponsiveSingleClick();
    new EmulateDoubleClick();

    /* In web app mode only: */
    if(window.navigator.standalone)
      MaintainUrlHash();

    SendMissingResizeEvents();
  }

  PreventDragScrolling();
}

SwipeHandler = function(element)
{
  this.element = element;
  this.dragger = new DragElement(element, { ondrag: this.ondrag.bind(this), onstartdrag: this.startdrag.bind(this) });
}

SwipeHandler.prototype.startdrag = function()
{
  this.swiped_horizontal = false;
  this.swiped_vertical = false;
}

SwipeHandler.prototype.ondrag = function(e)
{
  if(!this.swiped_horizontal)
  {
    // XXX: need a guessed DPI
    if(Math.abs(e.aX) > 100)
    {
      this.element.fire("swipe:horizontal", {right: e.aX > 0});
      this.swiped_horizontal = true;
    }
  }

  if(!this.swiped_vertical)
  {
    if(Math.abs(e.aY) > 100)
    {
      this.element.fire("swipe:vertical", {down: e.aY > 0});
      this.swiped_vertical = true;
    }
  }
}

SwipeHandler.prototype.destroy = function()
{
  this.dragger.destroy();
}



// script.aculo.us unittest.js v1.8.0, Tue Nov 06 15:01:40 +0300 2007

// Copyright (c) 2005-2007 Thomas Fuchs (http://script.aculo.us, http://mir.aculo.us)
//           (c) 2005-2007 Jon Tirsen (http://www.tirsen.com)
//           (c) 2005-2007 Michael Schuerig (http://www.schuerig.de/michael/)
//
// script.aculo.us is freely distributable under the terms of an MIT-style license.
// For details, see the script.aculo.us web site: http://script.aculo.us/

// experimental, Firefox-only
Event.simulateMouse = function(element, eventName) {
  var options = Object.extend({
    pointerX: 0,
    pointerY: 0,
    buttons:  0,
    ctrlKey:  false,
    altKey:   false,
    shiftKey: false,
    metaKey:  false
  }, arguments[2] || {});
  var oEvent = document.createEvent("MouseEvents");
  oEvent.initMouseEvent(eventName, true, true, document.defaultView, 
    options.buttons, options.pointerX, options.pointerY, options.pointerX, options.pointerY, 
    options.ctrlKey, options.altKey, options.shiftKey, options.metaKey, 0, $(element));
  
  if(this.mark) Element.remove(this.mark);
  this.mark = document.createElement('div');
  this.mark.appendChild(document.createTextNode(" "));
  document.body.appendChild(this.mark);
  this.mark.style.position = 'absolute';
  this.mark.style.top = options.pointerY + "px";
  this.mark.style.left = options.pointerX + "px";
  this.mark.style.width = "5px";
  this.mark.style.height = "5px;";
  this.mark.style.borderTop = "1px solid red;"
  this.mark.style.borderLeft = "1px solid red;"
  
  if(this.step)
    alert('['+new Date().getTime().toString()+'] '+eventName+'/'+Test.Unit.inspect(options));
  
  $(element).dispatchEvent(oEvent);
};

// Note: Due to a fix in Firefox 1.0.5/6 that probably fixed "too much", this doesn't work in 1.0.6 or DP2.
// You need to downgrade to 1.0.4 for now to get this working
// See https://bugzilla.mozilla.org/show_bug.cgi?id=289940 for the fix that fixed too much
Event.simulateKey = function(element, eventName) {
  var options = Object.extend({
    ctrlKey: false,
    altKey: false,
    shiftKey: false,
    metaKey: false,
    keyCode: 0,
    charCode: 0
  }, arguments[2] || {});

  var oEvent = document.createEvent("KeyEvents");
  oEvent.initKeyEvent(eventName, true, true, window, 
    options.ctrlKey, options.altKey, options.shiftKey, options.metaKey,
    options.keyCode, options.charCode );
  $(element).dispatchEvent(oEvent);
};

Event.simulateKeys = function(element, command) {
  for(var i=0; i<command.length; i++) {
    Event.simulateKey(element,'keypress',{charCode:command.charCodeAt(i)});
  }
};

var Test = {}
Test.Unit = {};

// security exception workaround
Test.Unit.inspect = Object.inspect;

Test.Unit.Logger = Class.create();
Test.Unit.Logger.prototype = {
  initialize: function(log) {
    this.log = $(log);
    if (this.log) {
      this._createLogTable();
    }
  },
  start: function(testName) {
    if (!this.log) return;
    this.testName = testName;
    this.lastLogLine = document.createElement('tr');
    this.statusCell = document.createElement('td');
    this.nameCell = document.createElement('td');
    this.nameCell.className = "nameCell";
    this.nameCell.appendChild(document.createTextNode(testName));
    this.messageCell = document.createElement('td');
    this.lastLogLine.appendChild(this.statusCell);
    this.lastLogLine.appendChild(this.nameCell);
    this.lastLogLine.appendChild(this.messageCell);
    this.loglines.appendChild(this.lastLogLine);
  },
  finish: function(status, summary) {
    if (!this.log) return;
    this.lastLogLine.className = status;
    this.statusCell.innerHTML = status;
    this.messageCell.innerHTML = this._toHTML(summary);
    this.addLinksToResults();
  },
  message: function(message) {
    if (!this.log) return;
    this.messageCell.innerHTML = this._toHTML(message);
  },
  summary: function(summary) {
    if (!this.log) return;
    this.logsummary.innerHTML = this._toHTML(summary);
  },
  _createLogTable: function() {
    this.log.innerHTML =
    '<div id="logsummary"></div>' +
    '<table id="logtable">' +
    '<thead><tr><th>Status</th><th>Test</th><th>Message</th></tr></thead>' +
    '<tbody id="loglines"></tbody>' +
    '</table>';
    this.logsummary = $('logsummary')
    this.loglines = $('loglines');
  },
  _toHTML: function(txt) {
    return txt.escapeHTML().replace(/\n/g,"<br/>");
  },
  addLinksToResults: function(){ 
    $$("tr.failed .nameCell").each( function(td){ // todo: limit to children of this.log
      td.title = "Run only this test"
      Event.observe(td, 'click', function(){ window.location.search = "?tests=" + td.innerHTML;});
    });
    $$("tr.passed .nameCell").each( function(td){ // todo: limit to children of this.log
      td.title = "Run all tests"
      Event.observe(td, 'click', function(){ window.location.search = "";});
    });
  }
}

Test.Unit.Runner = Class.create();
Test.Unit.Runner.prototype = {
  initialize: function(testcases) {
    this.options = Object.extend({
      testLog: 'testlog'
    }, arguments[1] || {});
    this.options.resultsURL = this.parseResultsURLQueryParameter();
    this.options.tests      = this.parseTestsQueryParameter();
    if (this.options.testLog) {
      this.options.testLog = $(this.options.testLog) || null;
    }
    if(this.options.tests) {
      this.tests = [];
      for(var i = 0; i < this.options.tests.length; i++) {
        if(/^test/.test(this.options.tests[i])) {
          this.tests.push(new Test.Unit.Testcase(this.options.tests[i], testcases[this.options.tests[i]], testcases["setup"], testcases["teardown"]));
        }
      }
    } else {
      if (this.options.test) {
        this.tests = [new Test.Unit.Testcase(this.options.test, testcases[this.options.test], testcases["setup"], testcases["teardown"])];
      } else {
        this.tests = [];
        for(var testcase in testcases) {
          if(/^test/.test(testcase)) {
            this.tests.push(
               new Test.Unit.Testcase(
                 this.options.context ? ' -> ' + this.options.titles[testcase] : testcase, 
                 testcases[testcase], testcases["setup"], testcases["teardown"]
               ));
          }
        }
      }
    }
    this.currentTest = 0;
    this.logger = new Test.Unit.Logger(this.options.testLog);
    setTimeout(this.runTests.bind(this), 1000);
  },
  parseResultsURLQueryParameter: function() {
    return window.location.search.parseQuery()["resultsURL"];
  },
  parseTestsQueryParameter: function(){
    if (window.location.search.parseQuery()["tests"]){
        return window.location.search.parseQuery()["tests"].split(',');
    };
  },
  // Returns:
  //  "ERROR" if there was an error,
  //  "FAILURE" if there was a failure, or
  //  "SUCCESS" if there was neither
  getResult: function() {
    var hasFailure = false;
    for(var i=0;i<this.tests.length;i++) {
      if (this.tests[i].errors > 0) {
        return "ERROR";
      }
      if (this.tests[i].failures > 0) {
        hasFailure = true;
      }
    }
    if (hasFailure) {
      return "FAILURE";
    } else {
      return "SUCCESS";
    }
  },
  postResults: function() {
    if (this.options.resultsURL) {
      new Ajax.Request(this.options.resultsURL, 
        { method: 'get', parameters: 'result=' + this.getResult(), asynchronous: false });
    }
  },
  runTests: function() {
    var test = this.tests[this.currentTest];
    if (!test) {
      // finished!
      this.postResults();
      this.logger.summary(this.summary());
      return;
    }
    if(!test.isWaiting) {
      this.logger.start(test.name);
    }
    test.run();
    if(test.isWaiting) {
      this.logger.message("Waiting for " + test.timeToWait + "ms");
      setTimeout(this.runTests.bind(this), test.timeToWait || 1000);
    } else {
      this.logger.finish(test.status(), test.summary());
      this.currentTest++;
      // tail recursive, hopefully the browser will skip the stackframe
      this.runTests();
    }
  },
  summary: function() {
    var assertions = 0;
    var failures = 0;
    var errors = 0;
    var messages = [];
    for(var i=0;i<this.tests.length;i++) {
      assertions +=   this.tests[i].assertions;
      failures   +=   this.tests[i].failures;
      errors     +=   this.tests[i].errors;
    }
    return (
      (this.options.context ? this.options.context + ': ': '') + 
      this.tests.length + " tests, " + 
      assertions + " assertions, " + 
      failures   + " failures, " +
      errors     + " errors");
  }
}

Test.Unit.Assertions = Class.create();
Test.Unit.Assertions.prototype = {
  initialize: function() {
    this.assertions = 0;
    this.failures   = 0;
    this.errors     = 0;
    this.messages   = [];
  },
  summary: function() {
    return (
      this.assertions + " assertions, " + 
      this.failures   + " failures, " +
      this.errors     + " errors" + "\n" +
      this.messages.join("\n"));
  },
  pass: function() {
    this.assertions++;
  },
  fail: function(message) {
    this.failures++;
    this.messages.push("Failure: " + message);
  },
  info: function(message) {
    this.messages.push("Info: " + message);
  },
  error: function(error) {
    this.errors++;
    this.messages.push(error.name + ": "+ error.message + "(" + Test.Unit.inspect(error) +")");
  },
  status: function() {
    if (this.failures > 0) return 'failed';
    if (this.errors > 0) return 'error';
    return 'passed';
  },
  assert: function(expression) {
    var message = arguments[1] || 'assert: got "' + Test.Unit.inspect(expression) + '"';
    try { expression ? this.pass() : 
      this.fail(message); }
    catch(e) { this.error(e); }
  },
  assertEqual: function(expected, actual) {
    var message = arguments[2] || "assertEqual";
    try { (expected == actual) ? this.pass() :
      this.fail(message + ': expected "' + Test.Unit.inspect(expected) + 
        '", actual "' + Test.Unit.inspect(actual) + '"'); }
    catch(e) { this.error(e); }
  },
  assertInspect: function(expected, actual) {
    var message = arguments[2] || "assertInspect";
    try { (expected == actual.inspect()) ? this.pass() :
      this.fail(message + ': expected "' + Test.Unit.inspect(expected) + 
        '", actual "' + Test.Unit.inspect(actual) + '"'); }
    catch(e) { this.error(e); }
  },
  assertEnumEqual: function(expected, actual) {
    var message = arguments[2] || "assertEnumEqual";
    try { $A(expected).length == $A(actual).length && 
      expected.zip(actual).all(function(pair) { return pair[0] == pair[1] }) ?
        this.pass() : this.fail(message + ': expected ' + Test.Unit.inspect(expected) + 
          ', actual ' + Test.Unit.inspect(actual)); }
    catch(e) { this.error(e); }
  },
  assertNotEqual: function(expected, actual) {
    var message = arguments[2] || "assertNotEqual";
    try { (expected != actual) ? this.pass() : 
      this.fail(message + ': got "' + Test.Unit.inspect(actual) + '"'); }
    catch(e) { this.error(e); }
  },
  assertIdentical: function(expected, actual) { 
    var message = arguments[2] || "assertIdentical"; 
    try { (expected === actual) ? this.pass() : 
      this.fail(message + ': expected "' + Test.Unit.inspect(expected) +  
        '", actual "' + Test.Unit.inspect(actual) + '"'); } 
    catch(e) { this.error(e); } 
  },
  assertNotIdentical: function(expected, actual) { 
    var message = arguments[2] || "assertNotIdentical"; 
    try { !(expected === actual) ? this.pass() : 
      this.fail(message + ': expected "' + Test.Unit.inspect(expected) +  
        '", actual "' + Test.Unit.inspect(actual) + '"'); } 
    catch(e) { this.error(e); } 
  },
  assertNull: function(obj) {
    var message = arguments[1] || 'assertNull'
    try { (obj==null) ? this.pass() : 
      this.fail(message + ': got "' + Test.Unit.inspect(obj) + '"'); }
    catch(e) { this.error(e); }
  },
  assertMatch: function(expected, actual) {
    var message = arguments[2] || 'assertMatch';
    var regex = new RegExp(expected);
    try { (regex.exec(actual)) ? this.pass() :
      this.fail(message + ' : regex: "' +  Test.Unit.inspect(expected) + ' did not match: ' + Test.Unit.inspect(actual) + '"'); }
    catch(e) { this.error(e); }
  },
  assertHidden: function(element) {
    var message = arguments[1] || 'assertHidden';
    this.assertEqual("none", element.style.display, message);
  },
  assertNotNull: function(object) {
    var message = arguments[1] || 'assertNotNull';
    this.assert(object != null, message);
  },
  assertType: function(expected, actual) {
    var message = arguments[2] || 'assertType';
    try { 
      (actual.constructor == expected) ? this.pass() : 
      this.fail(message + ': expected "' + Test.Unit.inspect(expected) +  
        '", actual "' + (actual.constructor) + '"'); }
    catch(e) { this.error(e); }
  },
  assertNotOfType: function(expected, actual) {
    var message = arguments[2] || 'assertNotOfType';
    try { 
      (actual.constructor != expected) ? this.pass() : 
      this.fail(message + ': expected "' + Test.Unit.inspect(expected) +  
        '", actual "' + (actual.constructor) + '"'); }
    catch(e) { this.error(e); }
  },
  assertInstanceOf: function(expected, actual) {
    var message = arguments[2] || 'assertInstanceOf';
    try { 
      (actual instanceof expected) ? this.pass() : 
      this.fail(message + ": object was not an instance of the expected type"); }
    catch(e) { this.error(e); } 
  },
  assertNotInstanceOf: function(expected, actual) {
    var message = arguments[2] || 'assertNotInstanceOf';
    try { 
      !(actual instanceof expected) ? this.pass() : 
      this.fail(message + ": object was an instance of the not expected type"); }
    catch(e) { this.error(e); } 
  },
  assertRespondsTo: function(method, obj) {
    var message = arguments[2] || 'assertRespondsTo';
    try {
      (obj[method] && typeof obj[method] == 'function') ? this.pass() : 
      this.fail(message + ": object doesn't respond to [" + method + "]"); }
    catch(e) { this.error(e); }
  },
  assertReturnsTrue: function(method, obj) {
    var message = arguments[2] || 'assertReturnsTrue';
    try {
      var m = obj[method];
      if(!m) m = obj['is'+method.charAt(0).toUpperCase()+method.slice(1)];
      m() ? this.pass() : 
      this.fail(message + ": method returned false"); }
    catch(e) { this.error(e); }
  },
  assertReturnsFalse: function(method, obj) {
    var message = arguments[2] || 'assertReturnsFalse';
    try {
      var m = obj[method];
      if(!m) m = obj['is'+method.charAt(0).toUpperCase()+method.slice(1)];
      !m() ? this.pass() : 
      this.fail(message + ": method returned true"); }
    catch(e) { this.error(e); }
  },
  assertRaise: function(exceptionName, method) {
    var message = arguments[2] || 'assertRaise';
    try { 
      method();
      this.fail(message + ": exception expected but none was raised"); }
    catch(e) {
      ((exceptionName == null) || (e.name==exceptionName)) ? this.pass() : this.error(e); 
    }
  },
  assertElementsMatch: function() {
    var expressions = $A(arguments), elements = $A(expressions.shift());
    if (elements.length != expressions.length) {
      this.fail('assertElementsMatch: size mismatch: ' + elements.length + ' elements, ' + expressions.length + ' expressions');
      return false;
    }
    elements.zip(expressions).all(function(pair, index) {
      var element = $(pair.first()), expression = pair.last();
      if (element.match(expression)) return true;
      this.fail('assertElementsMatch: (in index ' + index + ') expected ' + expression.inspect() + ' but got ' + element.inspect());
    }.bind(this)) && this.pass();
  },
  assertElementMatches: function(element, expression) {
    this.assertElementsMatch([element], expression);
  },
  benchmark: function(operation, iterations) {
    var startAt = new Date();
    (iterations || 1).times(operation);
    var timeTaken = ((new Date())-startAt);
    this.info((arguments[2] || 'Operation') + ' finished ' + 
       iterations + ' iterations in ' + (timeTaken/1000)+'s' );
    return timeTaken;
  },
  _isVisible: function(element) {
    element = $(element);
    if(!element.parentNode) return true;
    this.assertNotNull(element);
    if(element.style && Element.getStyle(element, 'display') == 'none')
      return false;
    
    return this._isVisible(element.parentNode);
  },
  assertNotVisible: function(element) {
    this.assert(!this._isVisible(element), Test.Unit.inspect(element) + " was not hidden and didn't have a hidden parent either. " + ("" || arguments[1]));
  },
  assertVisible: function(element) {
    this.assert(this._isVisible(element), Test.Unit.inspect(element) + " was not visible. " + ("" || arguments[1]));
  },
  benchmark: function(operation, iterations) {
    var startAt = new Date();
    (iterations || 1).times(operation);
    var timeTaken = ((new Date())-startAt);
    this.info((arguments[2] || 'Operation') + ' finished ' + 
       iterations + ' iterations in ' + (timeTaken/1000)+'s' );
    return timeTaken;
  }
}

Test.Unit.Testcase = Class.create();
Object.extend(Object.extend(Test.Unit.Testcase.prototype, Test.Unit.Assertions.prototype), {
  initialize: function(name, test, setup, teardown) {
    Test.Unit.Assertions.prototype.initialize.bind(this)();
    this.name           = name;
    
    if(typeof test == 'string') {
      test = test.gsub(/(\.should[^\(]+\()/,'#{0}this,');
      test = test.gsub(/(\.should[^\(]+)\(this,\)/,'#{1}(this)');
      this.test = function() {
        eval('with(this){'+test+'}');
      }
    } else {
      this.test = test || function() {};
    }
    
    this.setup          = setup || function() {};
    this.teardown       = teardown || function() {};
    this.isWaiting      = false;
    this.timeToWait     = 1000;
  },
  wait: function(time, nextPart) {
    this.isWaiting = true;
    this.test = nextPart;
    this.timeToWait = time;
  },
  run: function() {
    try {
      try {
        if (!this.isWaiting) this.setup.bind(this)();
        this.isWaiting = false;
        this.test.bind(this)();
      } finally {
        if(!this.isWaiting) {
          this.teardown.bind(this)();
        }
      }
    }
    catch(e) { this.error(e); }
  }
});

// *EXPERIMENTAL* BDD-style testing to please non-technical folk
// This draws many ideas from RSpec http://rspec.rubyforge.org/

Test.setupBDDExtensionMethods = function(){
  var METHODMAP = {
    shouldEqual:     'assertEqual',
    shouldNotEqual:  'assertNotEqual',
    shouldEqualEnum: 'assertEnumEqual',
    shouldBeA:       'assertType',
    shouldNotBeA:    'assertNotOfType',
    shouldBeAn:      'assertType',
    shouldNotBeAn:   'assertNotOfType',
    shouldBeNull:    'assertNull',
    shouldNotBeNull: 'assertNotNull',
    
    shouldBe:        'assertReturnsTrue',
    shouldNotBe:     'assertReturnsFalse',
    shouldRespondTo: 'assertRespondsTo'
  };
  var makeAssertion = function(assertion, args, object) { 
     this[assertion].apply(this,(args || []).concat([object]));
  }
  
  Test.BDDMethods = {};   
  $H(METHODMAP).each(function(pair) { 
    Test.BDDMethods[pair.key] = function() { 
       var args = $A(arguments); 
       var scope = args.shift(); 
       makeAssertion.apply(scope, [pair.value, args, this]); }; 
  });
  
  [Array.prototype, String.prototype, Number.prototype, Boolean.prototype].each(
    function(p){ Object.extend(p, Test.BDDMethods) }
  );
}

Test.context = function(name, spec, log){
  Test.setupBDDExtensionMethods();
  
  var compiledSpec = {};
  var titles = {};
  for(specName in spec) {
    switch(specName){
      case "setup":
      case "teardown":
        compiledSpec[specName] = spec[specName];
        break;
      default:
        var testName = 'test'+specName.gsub(/\s+/,'-').camelize();
        var body = spec[specName].toString().split('\n').slice(1);
        if(/^\{/.test(body[0])) body = body.slice(1);
        body.pop();
        body = body.map(function(statement){ 
          return statement.strip()
        });
        compiledSpec[testName] = body.join('\n');
        titles[testName] = specName;
    }
  }
  new Test.Unit.Runner(compiledSpec, { titles: titles, testLog: log || 'testlog', context: name });
};


UrlHashHandler = function()
{
  this.observers = new Hash();
  this.normalize = function(h) { }
  this.denormalize = function(h) { }
  this.deferred_sets = [];
  this.deferred_replace = false;

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

  var universal_observers = this.observers.get(null);
  if(universal_observers != null)
    observers_to_call = observers_to_call.concat(universal_observers);

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
    path = path.replace(/%/g, "%25").replace(/\?/g, "%3f");
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

UrlHashHandler.prototype.set_raw_hash = function(hash)
{
  var query_params = this.parse(hash);
  this.set_all(query_params);
}

UrlHashHandler.prototype.get = function(key)
{
  return this.current_hash.get(key);
}

/*
 * Set keys in the URL hash.
 *
 * UrlHash.set({id: 50});
 *
 * If replace is true and the History API is available, replace the state instead
 * of pushing it.
 */
UrlHashHandler.prototype.set = function(hash, replace)
{
  var new_hash = this.current_hash.merge(hash);
  this.normalize(new_hash);
  this.set_all(new_hash, replace);
}

/*
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
UrlHashHandler.prototype.set_deferred = function(hash, replace)
{
  this.deferred_sets.push(hash);
  if(replace)
    this.deferred_replace = true;

  var set = function()
  {
    this.deferred_set_timer = null;

    var new_hash = this.current_hash;
    this.deferred_sets.each(function(m) {
      new_hash = new_hash.merge(m);
    });
    this.normalize(new_hash);
    this.set_all(new_hash, this.deferred_replace);
    this.deferred_sets = [];

    this.hashchange_event(null);
    this.deferred_replace = false;
  }.bind(this);

  if(this.deferred_set_timer == null)
    this.deferred_set_timer = set.defer();
}


UrlHashHandler.prototype.set_all = function(query_params, replace)
{
  query_params = query_params.clone();

  this.normalize(query_params);
  this.current_hash = query_params.clone();

  this.denormalize(query_params);

  var new_hash = this.construct(query_params);
  if(window.location.hash != new_hash)
  {
    /* If the History API is available, use it to support URL replacement.  FF4.0's pushState
     * is broken; don't use it. */
    if(window.history && window.history.replaceState && window.history.pushState &&
        !navigator.userAgent.match("Firefox/[45]\."))
    {
      var url = window.location.protocol + "//" + window.location.host + window.location.pathname + new_hash;
      if(replace)
        window.history.replaceState({}, window.title, url);
      else
        window.history.pushState({}, window.title, url);
    }
    else
    {
      window.location.hash = new_hash;
    }
  }

  /* Explicitly fire the hashchange event, so it's handled quickly even if the browser
   * doesn't support the event.  It's harmless if we get this event multiple times due
   * to the browser delivering it normally due to our change. */
  this.hashchange_event(null);
}


/* Observe changes to the specified key.  If key is null, watch for all changes. */
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



User = {
  disable_samples: function() {
    new Ajax.Request("/user/update.json", {
      parameters: {
        "user[show_samples]": false
      },

      onComplete: function(resp) {
        var resp = resp.responseJSON

        if (resp.success) {
          $("resized_notice").hide();
          $("samples_disabled").show();
          Post.highres();
        } else {
          notice("Error: " + resp.reason)
        }
      }
    })
  },

  destroy: function(id) {
    notice("Deleting record #" + id)

    new Ajax.Request("/user_record/destroy.json", {
      parameters: {
        "id": id
      },
      onComplete: function(resp) {
        if (resp.status == 200) {
          notice("Record deleted")
        } else {
          notice("Access denied")
        }
      }
    })
  },

  current_check: null,
  cancel_check: function() {
    current_check = null;
  },

  /* If background is true, this is a request being made as an indirect result of other
   * input; these can be cancelled (rather, the result is ignord) and are automatically
   * cancelled if another is started while a previous one is still running.
   *
   * If background is false, this is an explicit user action (user submitted the form)
   * and the action must not be cancelled by unrelated background actions.
   */
  reset_password: function(username, email, func) {
    var new_check = new Ajax.Request("/user/reset_password.json", {
      parameters: {
        "user[name]": username,
        "user[email]": email
      },
      onComplete: function(resp) {
        var resp = resp.responseJSON;
        func(resp);
      }
    });
  },
  check: function(username, password, background, func) {
    var parameters = {
      "username": username
    }
    if(password)
      parameters.password = password;

    var new_check = new Ajax.Request("/user/check.json", {
      parameters: parameters,

      onSuccess: function(resp) {
        if(background && resp.request != current_check)
          return;
        current_check = null;

        var resp = resp.responseJSON;
        func(resp);

      }
    });
    if(background)
      current_check = new_check;
  },

  create: function(username, password, email, func) {
    var parameters = {
      "user[name]": username,
      "user[password]": password
    }
    if(email)
      parameters["user[email]"] = email;

    var new_check = new Ajax.Request("/user/create.json", {
      parameters: parameters,

      onComplete: function(resp) {
        var resp = resp.responseJSON;
        func(resp);
      }
    });
  },

  set_login: function(username, pass_hash, user_info)
  {
    Cookie.put("login", username)
    Cookie.put("pass_hash", pass_hash)
    Cookie.put("user_info", user_info)
  },

  check_name_timer: null,
  last_username_in_form: null,
  success_func: null,
  messages: [],

  init: function()
  {
    $("login-popup-notices").select("SPAN").each(function(e) {
      User.messages.push(e.id);
    });

    /*
     * IE makes us jump lots of hoops.  We have to watch submit events on every object
     * instead of just window because IE doesn't support event capturing.  We have to
     * override the submit method in every form to catch programmatic submits, because
     * IE doesn't seem to support initiating events by firing them.
     *
     * Also, since we can't capture events, we need to be sure our submit event is done
     * before other handlers, so if we cancel the event, we prevent other event handlers
     * from continuing.  However, we need to attach after forms have been created.  So,
     * this needs to be run as an early DOMLoaded event, and any other code that attaches
     * submit events to code needs to be run in a later DOMLoaded event (or later events).
     *
     */

    $$("FORM.need-signup").each(function(form) {
      form.observe("submit", User.run_login_onsubmit);
    });

    /* If you select an item from the history dropdown in IE7, change events never fire, so
     * use keyup instead.  This isn't a problem with password fields, since there's no history
     * dropdown. */
    $("login-popup").observe("submit", function(e) {
      e.stop(); 
      User.form_submitted();
    });

    $("login-popup-submit").observe("click", function(e) {
      e.stop();
      User.form_submitted();
    });

    $("login-popup-cancel").observe("click", function(e) { e.stop(); User.close(false); });
    $("login-popup-username").observe("blur", function(e) { User.form_username_blur(); });
    $("login-popup-username").observe("focus", function(e) { User.form_username_focus(); });
    $("login-popup-username").observe("keyup", function(e) { User.form_username_changed(true); });
    $("login-tabs").select("LI").each(function(a) { a.observe("mousedown", function(e) { e.stop(); }); });
    $("login-tabs").select("LI").each(function(a) { a.observe("click", function(e) { e.stop(); User.set_tab(a.id); }); });

    /* IE and FF are glitchy with form submission: they fail to submit forms unless
     * there's an <INPUT type="submit"> somewhere in the form.  IE is even worse:
     * even if there is one, if it's hidden on page load (including if it's a parent
     * element hidden), it'll never submit the form, even if it's shown later.  Don't
     * rely on this behavior; just catch enter presses and submit the form explicitly. */
    OnKey(13, {AllowInputFields: true, Element: $("login-popup")}, function(e)
    {
      e.stop();
      User.form_submitted();
    });

    /* Escape closes the login box. */
    OnKey(27, {AllowInputFields: true, AlwaysAllowOpera: true}, function(e)
    {
      if(!User.success_func)
        return false;

      User.close(false);
      return true;
    });
  },

  open: function(success)
  {
    if(User.success_func)
      User.close(false);
    User.success_func = success;

    $("login-background").show();
    $("login-container").show();

    User.set_tab("tab-login");
  },

  close: function(run_success_func)
  {
    if(!User.success_func)
      return;

    $("login-background").hide();
    $("login-container").hide();
    User.active_tab = null;
    User.check_name_timer = null;
    var func = User.success_func;
    User.success_func = null;

    success_func = null;
    if(run_success_func)
      window.setTimeout(func, 0);
  },

  /* Handle login from an onclick.  If login is not needed, return true.  Otherwise,
   * start the login, and return false; the object will receive another click when
   * the login is successful. */
  run_login_onclick: function(event)
  {
    event = Event.extend(event);

    /* event.target is not copied by clone_event. */
    var target = $(event.target);

    /* event is not available when we get to the callback in IE7. */
    var e = clone_event(event);

    if(User.run_login(true, function() {
        if(target.hasClassName("login-button"))
        {
          /* This is a login button, and not an action that happened to need login.  After
           * a successful login, don't click the button; that'll just go to the login page.
           * Instead, just reload the current page. */
          Cookie.put("notice", "You have been logged in.");
          document.location.reload();
          return;
        }
        target.simulate_anchor_click(e);
      }))
      return true;

    /* Login is running, so stop the event.  Don't just return false; call stop(), so
     * event.stopped is available to the caller if we've been sent this message via
     * Element.dispatchEvent. */
    event.stop();
    return false;
  },

  /* Handle login from an onsubmit.  If login is needed, stop the event and resubmit
   * it when the login completes.  If login is not needed, return and let the submit
   * complete normally. */
  run_login_onsubmit: function(event)
  {
    /* Set skip_complete_on_true, so if we don't need to login, we don't resubmit the
     * event; we just don't cancel it. */
    var target = $(event.target);
    if(!User.run_login(true, function() { target.simulate_submit(); }))
      event.stop();
  },

  /* Handle login.  If we're already logged in, run complete (unless only_complete_on_login
   * is true) and return true.  If we need to log in, start the login dialog; it'll call
   * complete() on successful login. */
  run_login: function(only_complete_on_login, complete)
  {
    if(Cookie.get("login") != "")
    {
      if(!only_complete_on_login)
        complete();
      return true;
    }

    User.open(complete);

    return false;
  },

  active_tab: null,
  set_tab: function(tab)
  {
    if(User.active_tab == tab)
      return;
    User.active_tab = tab;

    User.check_name_timer = null;
    User.last_username_in_form = null;

    $("login-tabs").select("LI").each(function(li) { li.removeClassName("selected"); });
    $("login-tabs").down("#" + tab).addClassName("selected");    


    $$(".tab-header-text").each(function(li) { li.hide(); });
    $(tab + "-text").show();

    if(tab == "tab-login")
    {
      /* If the user's browser fills in a username but no password, focus the password.  Otherwise,
       * focus the username. */
      if($("login-popup-password").value == "" && $("login-popup-username").value != "")
        $("login-popup-password").focus();
      else
        $("login-popup-username").focus();

      User.set_state("login-blank");
    }
    else if(tab == "tab-reset")
    {
      User.set_state("reset-blank");
      $("login-popup-username").focus();
    }
    User.form_username_changed();
  },

  message: function(text)
  {
    for (var i = 0, l = User.messages.length; i < l; i++) {
      var elem = User.messages[i];
      $(elem).hide();
    }

    $("login-popup-message").update(text);
    $("login-popup-message").show();
  },

  set_state: function(state)
  {
    var show = {};
    if(state.match(/^login-/))
    {
      show["login-popup-password-box"] = true;
      if(state == "login-blank")
        $("login-popup-submit").update("Login");
      else if(state == "login-user-exists")
        $("login-popup-submit").update("Login");
      else if(state == "login-confirm-password")
      {
        show["login-popup-password-confirm-box"] = true;
        $("login-popup-submit").update("Create account");
      }
      else if(state == "login-confirm-password-mismatch")
        $("login-popup-submit").update("Create account");
      show["login-popup-" + state] = true;
    }
    else if(state.match(/^reset-/))
    {
      show["login-popup-email-box"] = true;
      $("login-popup-submit").update("Reset password");

      show["login-popup-" + state] = true;
    }

    var all = ["login-popup-email-box", "login-popup-password-box", "login-popup-password-confirm-box"].concat(User.messages);

    current_state = state;
    for (var i = 0, l = all.length; i < l; i++) {
      var elem = all[i];
      if(show[elem])
        $(elem).show();
      else
        $(elem).hide();
    }
  },

  pending_username: null,
  form_username_changed: function(keyup)
  {
    var username = $("login-popup-username").value;
    if(username == User.last_username_in_form)
      return;
    User.last_username_in_form = username;

    User.cancel_check();
    if(User.check_name_timer)
      window.clearTimeout(User.check_name_timer);
    User.pending_username = null;

    if(username == "")
    {
      if(User.active_tab == "tab-login")
        User.set_state("login-blank");
      else if(User.active_tab == "tab-reset")
        User.set_state("reset-blank");
      return;
    }

    /* Delay on keyup, so we don't send tons of requests.  Don't delay otherwise,
     * so we don't introduce lag when we don't have to. */
    var ms = 500;
    if(!keyup && User.check_name_timer)
      ms = 0;

    /*
     * Make sure the UI is still usable if this never finished.  This way, we don't
     * lag the interface if these JSON requests are taking longer than usual; you should
     * be able to click "login" immediately as soon as a username and password are entered.
     * Entering a username and password and clicking "login" should still behave properly
     * if the username doesn't exist and the check_name_timer JSON request hasn't come
     * back yet.
     * 
     * If the state isn't "blank", the button is already enabled.
     */
    User.check_name_timer = window.setTimeout(function() {
      User.check_name_timer = null;
      User.check(username, null, true, function(resp)
      {
        if(resp.exists)
        {
          /* Update the username to match the actual user's case.  If the form contents have
           * changed since we started this check, don't do this.  (We cancel this event if we
           * see the contents change, but the contents can change without this event firing
           * at all.) */
          var current_username = $("login-popup-username").value;
          if(current_username == username)
          {
            /* If the element doesn't have focus, change the text to match.  If it does, wait
             * until it loses focus, so it doesn't interfere with the user editing it. */
            if(!$("login-popup").focused)
              $("login-popup-username").value = resp.name;
            else
              User.pending_username = resp.name;
          }
        }

        if(User.active_tab == "tab-login")
        {
          if(!resp.exists)
          {
            User.set_state("login-confirm-password");
            return;
          }
          else
            User.set_state("login-user-exists");
        }
        else if(User.active_tab == "tab-reset")
        {
          if(!resp.exists)
            User.set_state("reset-blank");
          else if(resp.no_email)
            User.set_state("reset-user-has-no-email");
          else
            User.set_state("reset-user-exists");
        }
      });
    }, ms);
  },

  form_username_focus: function()
  {
    $("login-popup").focused = true;
  },

  form_username_blur: function()
  {
    $("login-popup").focused = false;

    /* When the username field loses focus, update the username case to match the
     * result we got back from check(), if any. */
    if(User.pending_username)
    {
      $("login-popup").username.value = User.pending_username;
      User.pending_username = null;
    }

    /* We watch keyup on the username, because change events are unreliable in IE; update
     * when focus is lost, too, so we see changes made without using the keyboard. */
    User.form_username_changed(false);
  },

  form_submitted: function()
  {
    User.cancel_check();
    if(User.check_name_timer)
      window.clearTimeout(User.check_name_timer);

    var username = $("login-popup-username").value;
    var password = $("login-popup-password").value;
    var password_confirm = $("login-popup-password-confirm").value;
    var email = $("login-popup-email").value;

    if(username == "")
      return;

    if(User.active_tab == "tab-login")
    {
      if(password == "")
      {
        User.message("Please enter a password.");
        return;
      }

      if(current_state == "login-confirm-password")
      {
        if(password != password_confirm)
          User.message("The passwords you've entered don't match.");
        else
        {
          // create account
          User.create(username, password, null, function(resp) {
            if(resp.response == "success")
            {
              User.set_login(resp.name, resp.pass_hash, resp.user_info);
              User.close(true);
            }
            else if(resp.response == "error")
            {
              User.message(resp.errors.join("<br>"))
            }
          });
        }
        return;
      }

      User.check(username,  password, false, function(resp)
      {
        if(!resp.exists)
        {
          User.set_state("login-confirm-password");
          return;
        }

        /* We've authenticated successfully.  Our hash is in password_hash; insert the
         * login cookies manually. */
        if(resp.response == "wrong-password")
        {
          notice("Incorrect password");
          return;
        }
        User.set_login(resp.name, resp.pass_hash, resp.user_info);
        User.close(true);
      });
    }
    else if(User.active_tab == "tab-reset")
    {
      if(email == "")
        return;

      User.reset_password(username, email, function(resp)
      {
        if(resp.result == "success")
          User.set_state("reset-successful");
        else if(resp.result == "unknown-user")
          User.set_state("reset-unknown-user");
        else if(resp.result == "wrong-email")
          User.set_state("reset-user-email-incorrect");
        else if(resp.result == "no-email")
          User.set_state("reset-user-has-no-email");
        else if(resp.result == "invalid-email")
          User.set_state("reset-user-email-invalid");
      });
    }
  },

  modify_blacklist: function(add, remove, success)
  {
    new Ajax.Request("/user/modify_blacklist.json", {
      parameters: {
        "add[]": add,
        "remove[]": remove
      },
      onComplete: function(resp) {
        var resp = resp.responseJSON;

        if (resp.success)
        {
          if(success) success(resp);
        } else {
          notice("Error: " + resp.reason);
        }
      }
    });
  },

  set_pool_browse_mode: function(browse_mode) {
    new Ajax.Request("/user/update.json", {
      parameters: {
        "user[pool_browse_mode]": browse_mode
      },

      onComplete: function(resp) {
        var resp = resp.responseJSON;

        if (resp.success) {
          window.location.reload();
        } else {
          notice("Error: " + resp.reason);
        }
      }
    });
  },

  get_current_user_info: function()
  {
    var user_info = Cookie.get("user_info");
    if(!user_info)
      return null;
    return user_info.split(";");
  },
  get_current_user_info_field: function(idx, def)
  {
    var user_info = User.get_current_user_info();
    if(!user_info)
      return def;
    if(idx >= user_info.length)
      return def;
    return user_info[idx];
  },
  get_current_user_id: function()
  {
    return parseInt(User.get_current_user_info_field(0, 0));
  },

  get_current_user_level: function()
  {
    return parseInt(User.get_current_user_info_field(1, 0));
  },

  get_use_browser: function()
  {
    var setting = User.get_current_user_info_field(2, "0");
    return setting == "1";
  },

  is_member_or_higher: function()
  {
    return User.get_current_user_level() >= 20;
  },

  is_mod_or_higher: function()
  {
    return User.get_current_user_level() >= 40;
  }
}



UserRecord = {
  destroy: function(id) {
    notice('Deleting record #' + id)

    new Ajax.Request('/user_record/destroy.json', {
      parameters: {
        "id": id
      },
      onComplete: function(resp) {
        if (resp.status == 200) {
          notice("Record deleted")
        } else {
          notice("Access denied")
        }
      }
    })
  }
}


VoteWidget = function(container)
{
  this.container = container;
  this.post_id = null;
  this.displayed_hover = -1;
  this.displayed_set = -1;

  if(container.down(".vote-up"))
    container.down(".vote-up").on("click", function(e) { e.stop(); this.vote_up(); }.bindAsEventListener(this));

  var vote_descs =
  {
    "0": "Remove vote",
    "1": "Good",
    "2": "Great",
    "3": "Favorite"
  };

  for(var stars = 0; stars <= 3; ++stars)
  {
    var s = this.container.down(".star-" + stars);
    if(!s)
      continue;
    s.star = stars;
    s.desc = vote_descs[stars];
  }

  this.container.on("click", ".star", function(e) { e.stop(); this.activate_item(e.target); }.bindAsEventListener(this));
  this.container.on("mouseover", ".star", function(e) { this.set_mouseover(e.target); }.bindAsEventListener(this));
  this.container.on("mouseout", ".star", function(e) { this.set_mouseover(e.relatedTarget); }.bindAsEventListener(this));

  document.on("posts:update", this.post_update_event.bindAsEventListener(this));
}

VoteWidget.prototype.get_star_element = function(element)
{
  if(!element)
    return null;
  if(element.hasClassName("star"))
    return element;
  else
    return element.up(".star");
}

VoteWidget.prototype.set_mouseover = function(element)
{
  if(element)
    element = this.get_star_element(element);
  if(!element)
  {
    this.set_stars(null);
    var text = this.container.down(".vote-desc");
    if(text)
      text.update();
    return false;
  }
  else
  {
    this.set_stars(element.star);
    var text = this.container.down(".vote-desc");
    if(text)
      text.update(element.desc);
    return true;
  }
}

VoteWidget.prototype.activate_item = function(element)
{
  element = this.get_star_element(element);
  if(!element)
    return null;
  this.vote(element.star);
  return element.star;
}


/* One or more posts have been updated; see if the vote we should be displaying
 * has changed. */
VoteWidget.prototype.post_update_event = function(e)
{
  var post_id = this.post_id;
  if(e.memo.post_ids.get(post_id) == null)
    return;

  this.set_stars(this.displayed_hover);

  if(this.container.down("#post-score-" + post_id))
  {
    var post = Post.posts.get(post_id);
    if(post)
      this.container.down("#post-score-" + post_id).update(post.score)
  }

  if(e.memo.resp.voted_by && this.container.down("#favorited-by")) {
    this.container.down("#favorited-by").update(Favorite.link_to_users(e.memo.resp.voted_by["3"]))
  }
}

VoteWidget.prototype.set_post_id = function(post_id)
{
  var vote = Post.votes.get(post_id) || 0;
  this.post_id = post_id;
  this.set_stars(null);
}

VoteWidget.prototype.init_hotkeys = function()
{
  OnKey(192, null, function(e) { this.vote(+0); return true; }.bindAsEventListener(this)); // `
  OnKey(49, null, function(e) { this.vote(+1); return true; }.bindAsEventListener(this));
  OnKey(50, null, function(e) { this.vote(+2); return true; }.bindAsEventListener(this));
  OnKey(51, null, function(e) { this.vote(+3); return true; }.bindAsEventListener(this));
}

VoteWidget.prototype.vote_up = function()
{
  var current_vote = Post.votes.get(this.post_id);
  return this.vote(current_vote + 1);
}

VoteWidget.prototype.vote = function(score)
{
  return Post.vote(this.post_id, score);
}

var array_select = function(list, y, n, val)
{
  if(val)
    list.push(y);
  else
    list.push(n);
}

VoteWidget.prototype.set_stars = function(hovered_vote)
{
  var set_vote = Post.votes.get(this.post_id);

  if(this.displayed_hover == hovered_vote && this.displayed_set == set_vote)
    return;
  this.displayed_hover = hovered_vote;
  this.displayed_set = set_vote;

  for(var star_vote = 0; star_vote <= 3; ++star_vote)
  {
    var star = this.container.down(".star-" + star_vote);
    if(!star)
      continue;
    var className = star.className;
    className = className.replace(/(star-hovered|star-unhovered|star-hovered-upto|star-hovered-after|star-set|star-unset|star-set-upto|star-set-after)(\s+|$)/g, " ");
    className = className.strip();
    var classes = className.split(" ");

    if(hovered_vote != null)
    {
      array_select(classes, "star-hovered", "star-unhovered", hovered_vote == star_vote);
      array_select(classes, "star-hovered-upto", "star-hovered-after", hovered_vote >= star_vote);
    }
    array_select(classes, "star-set", "star-unset", set_vote != null && set_vote == star_vote);
    array_select(classes, "star-set-upto", "star-set-after", set_vote != null && set_vote >= star_vote);

    star.className = classes.join(" ");
  }
}

