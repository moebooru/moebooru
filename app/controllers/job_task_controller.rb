class JobTaskController < ApplicationController
  layout "default"
  
  def index
    @job_tasks = JobTask.paginate(:per_page => 25, :order => "id DESC", :page => params[:page])
  end
  
  def show
    @job_task = JobTask.find(params[:id])
    
    if @job_task.task_type == "upload_post" && @job_task.status == "finished"
      redirect_to :controller => "post", :action => "show", :id => @job_task.status_message
    end
  end
  
  def retry
    @job_task = JobTask.find(params[:id])

    if request.post?
      @job_task.update_attributes(:status => "pending", :status_message => "")
      redirect_to :action => "show", :id => @job_task.id
    end
  end
end
