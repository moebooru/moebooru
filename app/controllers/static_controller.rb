class StaticController < ApplicationController
  layout "bare"
  caches_page :opensearch
end
