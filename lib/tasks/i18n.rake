namespace :i18n do
  desc 'Find missing translations for each locales.'
  task :find_missing => :environment do
    @reference = 'en'

    def print_header(text, line)
      puts text
      puts line * text.length
    end

    def yaml_path(locale)
      Rails.root.join('config', 'locales', "#{locale}.yml")
    end

    def find_changes(target)
      yaml_reference = YAML.load(File.open(File.expand_path(yaml_path(@reference))))
      yaml_target = YAML.load(File.open(File.expand_path(yaml_path(target))))

      def compare(yaml_1, yaml_2)
        def flatten_keys(hash, prefix="")
          keys = []
          hash.keys.each do |key|
            if hash[key].is_a? Hash
              current_prefix = prefix + "#{key}."
              keys << flatten_keys(hash[key], current_prefix)
            else
              keys << "#{prefix}#{key}"
            end
          end
          prefix == "" ? keys.flatten : keys
        end
        keys_1 = flatten_keys(yaml_1[yaml_1.keys.first])
        keys_2 = flatten_keys(yaml_2[yaml_2.keys.first])

        return keys_2 - keys_1
      end

      removed = compare(yaml_reference, yaml_target)
      added = compare(yaml_target, yaml_reference)
      if added.any? or removed.any?
        if added.any?
          puts "Missing translations for #{target}:"
          added.each { |key| puts "  + #{key}" }
          puts
        end
        if removed.any?
          puts "Unused translations for #{target}:"
          removed.each { |key| puts "  - #{key}" }
          puts
        end
      else
        puts "Translation for #{target} is up to date."
      end
    end

    CONFIG['available_locales'].each do |l|
      next if l == @reference
      print_header "Report for locale '#{l}'", '='
      find_changes l
      puts
    end
  end
end
