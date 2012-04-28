# Drop this file in config/initializers to run your Rails project on Ruby 1.9.
# This is two separate monkey patches -- see comments in code below for the source of each. 
# None of them are original to me, I just put them in one file for easily dropping into my Rails projects.
# Also see original sources for pros and cons of each patch.
# The original gist also contained a patch for the mysql gem but you should use mysql2 on Ruby 1.9 instead; it's mysql + unicode + unicorns!
#
# Andre Lewis 1/2010 
# Joost Baaij 2/2011
# https://gist.github.com/838489


# encoding: utf-8

if RUBY_VERSION.to_f >= 1.9

  #
  # Source: https://rails.lighthouseapp.com/projects/8994/tickets/2188-i18n-fails-with-multibyte-strings-in-ruby-19-similar-to-2038
  # (fix_params.rb)

  module ActionController
    class Request
      private

        # Convert nested Hashs to HashWithIndifferentAccess and replace
        # file upload hashs with UploadedFile objects
        def normalize_parameters(value)
          case value
          when Hash
            if value.has_key?(:tempfile)
              upload = value[:tempfile]
              upload.extend(UploadedFile)
              upload.original_path = value[:filename]
              upload.content_type = value[:type]
              upload
            else
              h = {}
              value.each { |k, v| h[k] = normalize_parameters(v) }
              h.with_indifferent_access
            end
          when Array
            value.map { |e| normalize_parameters(e) }
          else
            value.force_encoding(Encoding::UTF_8) if value.respond_to?(:force_encoding)
            value
          end
        end
    end
  end


  #
  # Source: https://rails.lighthouseapp.com/projects/8994/tickets/2188-i18n-fails-with-multibyte-strings-in-ruby-19-similar-to-2038
  # (fix_renderable.rb)
  #
  module ActionView
    module Renderable #:nodoc:
      private
        def compile!(render_symbol, local_assigns)
          locals_code = local_assigns.keys.map { |key| "#{key} = local_assigns[:#{key}];" }.join

          source = <<-end_src
            def #{render_symbol}(local_assigns)
              old_output_buffer = output_buffer;#{locals_code};#{compiled_source}
            ensure
              self.output_buffer = old_output_buffer
            end
          end_src
          source.force_encoding(Encoding::UTF_8) if source.respond_to?(:force_encoding)

          begin
            ActionView::Base::CompiledTemplates.module_eval(source, filename, 0)
          rescue Errno::ENOENT => e
            raise e # Missing template file, re-raise for Base to rescue
          rescue Exception => e # errors from template code
            if logger = defined?(ActionController) && Base.logger
              logger.debug "ERROR: compiling #{render_symbol} RAISED #{e}"
              logger.debug "Function body: #{source}"
              logger.debug "Backtrace: #{e.backtrace.join("\n")}"
            end

            raise ActionView::TemplateError.new(self, {}, e)
          end
        end
    end
  end
end
