# extensions to Rails and Ruby and whatever are located in config/core_ext/*.rb
Dir[File.join(Rails.root, "config", "core_ext", "*.rb")].each { |l| require l }
