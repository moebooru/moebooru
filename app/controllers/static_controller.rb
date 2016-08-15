class StaticController < ApplicationController
  layout "bare"

  def opensearch
    respond_to { |format| format.xml }
  end
end
