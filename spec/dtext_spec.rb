require 'helper.rb'

describe "Header" do

  it "- should acknowledge h1 to h6" do
    (1..6).each { |i|
      p("h#{i}. header").should eq("<h#{i}>header</h#{i}>")
    }
  end

  it "- for each tag, should separated by at least a single newline" do
    p("h1. header1\nh2. header2\nh3. header3").should(
      eq("<h1>header1</h1><h2>header2</h2><h3>header3</h3>")
    )
    p("h1. header1\n\n\nh2. header2\n\nh3. header3").should(
      eq("<h1>header1</h1><h2>header2</h2><h3>header3</h3>")
    )
  end

  it "- not an inline tag" do
    p("start h1. paragraph no header").should eq "start h1. paragraph no header"
  end

end


describe "List" do

  it "- translate to unnembered list" do
    p("* lol").should eq "<ul><li>lol</li></ul>"
  end

  it "- each item separated by a single newline" do
    p("* lol\n* next\n* last").should eq "<ul><li>lol</li><li>next</li><li>last</li></ul"
  end

  it "- list and non list tag line separated by a single newline" do
    p("this is not a list\n* now this is a list\n* continue the list\nno I'm not").should(
      eq "this is not a list<ul><li>now this is a list</li><li>continue the list</li></ul>noI'm not"
    )
  end

  it "- can has multiple nested list" do
  end

end


describe "Paragraph" do
  it "- ended with a blank line" do
    p("Hello there\nDon't believe we've met before.\n\nhaha").should(
      eq "<p>Hello there<br>Don't believe we've met before.</p>haha"
    )
    p("not a paragraph?").should_not eq "<p>not a paragraph?</p>"
    p("this is a paragraph\n\n").should eq "<p>this is a paragraph</p>"
  end
end


describe "Link" do 
end


describe "Spoiler" do
end


describe "Special chars" do
  it "- '>' translates to &gt;" do
    p(">").should eq "&gt;"
  end

  it "- '<' translates to &lt;" do
    p("<").should eq "&lt;"
  end

  it "- '&' translates to &amp;" do
    p("&").should eq "&amp;"
  end
end
