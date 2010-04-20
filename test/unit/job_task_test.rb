require File.dirname(__FILE__) + '/../test_helper'

class JobTaskTest < ActiveSupport::TestCase
  fixtures :users
  
  def test_all
    begin
      ta = TagAlias.create(:name => "a", :alias => "b", :creator_id => 1, :is_pending => true)
      JobTask.create(:task_type => "approve_tag_alias", :status => "pending", :data => {"id" => ta.id, "updater_id" => 1, "updater_ip_addr" => "127.0.0.1"})
      JobTask.execute_once
      ta.reload
      assert(!ta.is_pending?)
    ensure
      TagAlias.delete_all
      JobTask.delete_all
    end
  end
end if CONFIG["enable_asynchronous_tasks"]
