class UploadsController < ApplicationController
  before_action :authenticate_user!

  def new
    @upload = Upload.new(user_id: current_user.id, user_type: "User").tap(&:save)
  end

  def create
    @upload = Upload.new(upload_params)

    if @upload.save
      redirect_to @upload, notice: 'Document was successfully uploaded.'
    else
      render action: 'new'
    end
  end

  def download
    @upload = Upload.find(params[:id].to_i)
    redirect_to @upload.file.expiring_url(url_expire_in_seconds)
  end

  private

  def url_expire_in_seconds
    10
  end

  def upload_params
    params.require(:upload).permit(:file, :file_file_name, :user_id, :user_type)
  end
end
