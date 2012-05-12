require './lib/dtext.rb'

include DText

TestDir = "./tests"

def p(str)
  DText.parse(str)
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
