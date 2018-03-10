require "yaml"

class RemoveYaml < ActiveRecord::Migration[5.1]
  def self.up
    Tag.find(:all).each do |tag|
      mapping = YAML.load(tag.cached_related)
      tag.cached_related = mapping.flatten.join(",")
      tag.save
    end
  end

  def self.down
  end
end
