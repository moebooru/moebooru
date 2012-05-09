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
    p("start h1. paragraph no header").should eq "<p>start h1. paragraph no header</p>"
  end
end


describe "List" do
end


describe "Paragraph" do
end


describe "Link" do 
end


describe "Spoiler" do
end


describe "Special chars" do
  it "- '>' translates to &gt;" do
    p(">").should eq "<p>&gt;</p>"
  end

  it "- '<' translates to &lt;" do
    p("<").should eq "<p>&lt;</p>"
  end

  it "- '&' translates to &amp;" do
    p("&").should eq "<p>&amp;</p>"
  end
end
