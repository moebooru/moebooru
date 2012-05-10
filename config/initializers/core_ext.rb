# extensions to Rails and Ruby and whatever are located in lib/core_ext/*.rb
Dir[File.join(Rails.root, "lib", "core_ext", "*.rb")].each {|l| require l }
