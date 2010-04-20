class User < ActiveRecord::Base
end

class UserBlacklistedTags < ActiveRecord::Base
end

class CreateUserBlacklistedTags < ActiveRecord::Migration
  def self.up
    create_table :user_blacklisted_tags do |t|
      t.column :user_id, :integer, :null => false
      t.column :tags, :text, :null => false
    end
    
    add_index :user_blacklisted_tags, :user_id
    
    add_foreign_key :user_blacklisted_tags, :user_id, :users, :id, :on_delete => :cascade
    UserBlacklistedTags.reset_column_information    

    User.find(:all, :order => "id").each do |user|
      unless user[:blacklisted_tags].blank?
        tags = user[:blacklisted_tags].scan(/\S+/).each do |tag|
          UserBlacklistedTags.create(:user_id => user.id, :tags => tag)
        end
      end
    end
    
    remove_column :users, :blacklisted_tags
  end

  def self.down
    drop_table :user_blacklisted_tags
    add_column :users, :blacklisted_tags, :text, :null => false, :default => ""
  end
end

