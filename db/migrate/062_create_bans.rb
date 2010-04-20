class CreateBans < ActiveRecord::Migration
  def self.up
    create_table :bans do |t|
      t.column :user_id, :integer, :null => false
      t.foreign_key :user_id, :users, :id, :on_delete => :cascade
      t.column :reason, :text, :null => false
      t.column :expires_at, :datetime, :null => false
      t.column :banned_by, :integer, :null => false
      t.foreign_key :banned_by, :users, :id, :on_delete => :cascade
    end
    
    add_index :bans, :user_id
    
    User.find(:all, :conditions => ["level = 0 or level = 1"]).each do |user|
      user.update_attribute(:level, User::LEVEL_BLOCKED)
      Ban.create(:user_id => user.id, :reason => "Grandfathered", :banned_by => 1, :expires_at => 7.days.from_now)
    end
  end

  def self.down
    drop_table :bans
  end
end
