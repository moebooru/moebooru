class CreateDmails < ActiveRecord::Migration
  def self.up
    transaction do
      create_table :dmails do |t|
        t.column :from_id, :integer, :null => false
        t.foreign_key :from_id, :users, :id, :on_delete => :cascade
        t.column :to_id, :integer, :null => false
        t.foreign_key :to_id, :users, :id, :on_delete => :cascade
        t.column :title, :text, :null => false
        t.column :body, :text, :null => false
        t.column :created_at, :timestamp, :null => false
        t.column :has_seen, :boolean, :null => false, :default => false
      end
    
      add_index :dmails, :from_id
      add_index :dmails, :to_id
    
      add_column :users, :has_mail, :boolean, :default => false, :null => false
    end
  end

  def self.down
    drop_table :dmails
    remove_column :users, :has_mail
  end
end
