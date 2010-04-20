ENV["RAILS_ENV"] = "test"

require File.dirname(__FILE__) + "/../config/environment"
require 'test_help'

CONFIG["enable_parent_posts"] = true
CONFIG["enable_account_email_activation"] = true

# Password for all users is password1

# def create_fixtures(*table_names)
#   Fixtures.create_fixtures(File.dirname(__FILE__) + "/fixtures", table_names)
# end

def create_cookie(key, value, domain = "")
	CGI::Cookie.new("name" => key, "value" => value, "expires" => 1.year.from_now, "path" => "/", "domain" => domain)
end

def upload_file(path, content_type, filename)
	t = Tempfile.new(filename)
	FileUtils.copy_file(path, t.path)
	(class << t; self; end).class_eval do
		alias local_path path
		define_method(:original_filename) {filename}
		define_method(:content_type) {content_type}
	end

	t
end

def upload_jpeg(path)
	upload_file(path, "image/jpeg", File.basename(path))
end

class Test::Unit::TestCase
  self.use_transactional_fixtures = true
  self.use_instantiated_fixtures = false
end

class ActiveSupport::TestCase
  def assert_greater(expected, actual, message=nil)
    full_message = build_message(message, <<EOT, expected, actual)
<?> > <?> expected.
EOT
    assert_block(full_message) { expected > actual }
  end
end
