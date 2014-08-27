class StaticController < ApplicationController
  layout "bare"
  caches_page :opensearch

  def opensearch
    respond_to { |format| format.xml }
  end
end
