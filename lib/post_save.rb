# post_save is run after the save has completed, all after_save callbacks have
# been run, and the attribute dirty flags have been cleared by save_with_dirty.
# This callback is useful for any post-save behavior that may need to call
# self.save again.  We must not save in after_save, because it'll cause
# lib/versioning to save duplicate history records (due to dirty flags not
# being cleared yet).

module ActiveRecord
  module PostSave
    def self.included(base)
      base.define_callbacks :post_save
      base.alias_method_chain :save,            :post_callback
      base.alias_method_chain :save!,           :post_callback
    end

    def save_with_post_callback!(*args)
      status = save_without_post_callback!(*args)
      run_callbacks(:post_save)
      status
    end

    def save_with_post_callback(*args)
      if status = save_without_post_callback(*args)
        run_callbacks(:post_save)
      end
      status
    end
  end
end

ActiveRecord::Base.send :include, ActiveRecord::PostSave
