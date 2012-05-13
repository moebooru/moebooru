require 'helper.rb'

describe "DText" do
  test = find_test()
  test.each do |t|
    match = t.gsub /\.txt$/, '.html'
    it t do
      p(r(t)).should eq(h(match))
    end
  end
end

