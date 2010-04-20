require 'html5sanitizer'
ActionView::Base.send :include, HTML5Sanitizer
