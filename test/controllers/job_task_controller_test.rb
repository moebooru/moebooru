require "test_helper"

class JobTaskControllerTest < ActionController::TestCase
  def test_all
    job_task = JobTask.create(task_type: "mass_tag_edit", status: "pending", data: { "start" => "a", "result" => "b", "updater_id" => 1, "updater_ip_addr" => "127.0.0.1" })

    assert_equal([], job_task.errors.full_messages)

    get :index
    assert_response :success

    get :show, params: { id: job_task.id }, session: { user_id: 1 }
    assert_response :success

    get :restart, params: { id: job_task.id }, session: { user_id: 1 }
    assert_response :success
  end
end
