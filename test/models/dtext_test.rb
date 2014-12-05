require "minitest/spec"
require "minitest/autorun"

require File.expand_path("../dtext/helper.rb", __FILE__)

describe DText do
  tests = find_test
  tests.each do |t|
    match = t.gsub /\.txt$/, ".html"
    it t do
      assert_equal h(match), p(r(t))
    end
  end

  it "does not explode on nil" do
    assert_equal "", p(nil)
  end
end
