class CreateAdvertisements < ActiveRecord::Migration
  def self.up
    create_table :advertisements do |t|
      t.column :image_url, :string, :null => false
      t.column :referral_url, :string, :null => false
      t.column :ad_type, :string, :null => false
      t.column :status, :string, :null => false
      t.column :hit_count, :integer, :null => false, :default => 0
      t.column :width, :integer, :null => false
      t.column :height, :integer, :null => false
    end

    execute "insert into advertisements (image_url, referral_url, ad_type, status, hit_count, width, height) values ('/images/180x300_1.jpg', 'http://affiliates.jlist.com/click/2253?url=http://www.jlist.com/index.html', 'vertical', 'active', 0, 180, 300)"
    execute "insert into advertisements (image_url, referral_url, ad_type, status, hit_count, width, height) values ('/images/180x300_2.jpg', 'http://affiliates.jlist.com/click/2253?url=http://www.jlist.com/index.html', 'vertical', 'active', 0, 180, 300)"
    execute "insert into advertisements (image_url, referral_url, ad_type, status, hit_count, width, height) values ('/images/180x300_3.jpg', 'http://affiliates.jlist.com/click/2253?url=http://www.jlist.com/index.html', 'vertical', 'active', 0, 180, 300)"

    execute "insert into advertisements (image_url, referral_url, ad_type, status, hit_count, width, height) values ('/images/728x90_1.jpg', 'http://affiliates.jlist.com/click/2253?url=http://www.jlist.com/index.html', 'horizontal', 'active', 0, 728, 90)"
    execute "insert into advertisements (image_url, referral_url, ad_type, status, hit_count, width, height) values ('/images/728x90_2.jpg', 'http://affiliates.jlist.com/click/2253?url=http://www.jlist.com/index.html', 'horizontal', 'active', 0, 728, 90)"
    execute "insert into advertisements (image_url, referral_url, ad_type, status, hit_count, width, height) values ('/images/728x90_3.jpg', 'http://affiliates.jlist.com/click/2253?url=http://www.jlist.com/index.html', 'horizontal', 'active', 0, 728, 90)"
    execute "insert into advertisements (image_url, referral_url, ad_type, status, hit_count, width, height) values ('/images/728x90_4.jpg', 'http://affiliates.jlist.com/click/2253?url=http://www.jlist.com/index.html', 'horizontal', 'active', 0, 728, 90)"

  end

  def self.down
    drop_table :advertisements
  end
end
