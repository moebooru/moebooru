require "test_helper"
require_relative "./dtext/helper"

describe DText do
  tests = DTextHelper.find_test
  tests.each do |t|
    match = t.gsub /\.txt$/, ".html"
    it t do
      assert_equal DTextHelper.h(match), DTextHelper.p(DTextHelper.r(t))
    end
  end

  it "does not explode on nil" do
    assert_equal "", DTextHelper.p(nil)
  end
end
