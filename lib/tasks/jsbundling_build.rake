# Mostly lifted from [1] but replace yarn with npm
# [1] https://github.com/rails/jsbundling-rails/blob/98780f28809ebad5d84921ce38dc238472a35812/lib/tasks/jsbundling/build.rake

# First clear existing task actions
Rake::Task["javascript:build"].clear_actions

namespace :javascript do
  desc "Build your JavaScript bundle"
  task :build do
    unless system "npm install && npm run build"
      raise "jsbundling-rails: Command build failed, ensure npm is installed and `npm run build` runs without errors"
    end
  end
end
