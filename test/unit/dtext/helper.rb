require "./lib/dtext.rb"
require "nokogiri"

include DText

TestDir = File.expand_path("../tests", __FILE__)

def p(str)
  DText.parse(str).gsub(/>\s*</, "><").gsub(/\n*/, "")
end

def find_test()
  begin
    test = Dir.entries(TestDir).select { |f| f =~ /^[^\.](?=.*\.txt$)/ }
  rescue
    print "Read #{TestDir} error\n"
    return []
  end
  test.map! { |f|  "#{TestDir}/#{f}" }
  test.sort
end

def r(f)
  begin
    ct = File.read(f)
  rescue
    print "Read #{f} error\n"
    return ""
  end
  ct.strip
end

def h(f)
  Nokogiri::HTML::DocumentFragment.parse(r(f)).to_html.gsub(/>\s*</, "><").gsub(/\n+\s*/, "")
end
