ENV["RAILS_ENV"] = "test"
require File.expand_path("../../config/environment", __FILE__)
require "rails/test_help"

class ActiveSupport::TestCase
  # Setup all fixtures in test/fixtures/*.(yml|csv) for all tests in alphabetical order.
  #
  # Note: You'll currently still have to declare fixtures explicitly in integration tests
  # -- they do not yet inherit this setting
  fixtures :all

  def upload_file(path)
    t = Tempfile.new File.basename(path)
    FileUtils.copy_entry File.open(path, "rb"), t
    t.rewind
    t
  end

  setup :reset_thread_variables

  private

  def reset_thread_variables
    %w(danbooru-user danbooru-user_id).each do |x|
      Thread.current[x] = nil
    end
  end
end
