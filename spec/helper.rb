require './lib/dtext.rb'

include DText

def p(str)
  DText.parse(str)
end
