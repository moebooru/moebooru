require File.expand_path('../auto_complete-rails3/auto_complete.rb', __FILE__)
require File.expand_path('../auto_complete-rails3/auto_complete_form_builder_helper.rb', __FILE__)
require File.expand_path('../auto_complete-rails3/auto_complete_macros_helper.rb', __FILE__)
require File.expand_path('../auto_complete-rails3/view_mapper/has_many_auto_complete_view.rb', __FILE__)

ActionController::Base.send :include, AutoComplete
ActionController::Base.helper AutoCompleteMacrosHelper
ActionView::Helpers::FormBuilder.send :include, AutoCompleteFormBuilderHelper
