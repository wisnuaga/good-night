class FollowsController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :set_current_user

  # POST /users/:id/following
  def follow
    if current_user.id == params[:id].to_i
      render_result(
        result: OpenStruct.new(success?: false, error: "Cannot follow yourself"),
        status: :bad_request
      )
      return
    end

    result = FollowUsecase::Follow.new(current_user, params[:id].to_i).call
    render_result(result: result, status: :created)
  end

  # DELETE /users/:id/following
  def unfollow
    result = FollowUsecase::Unfollow.new(current_user, params[:id].to_i).call
    render_result(result: result, status: :ok)
  end
end
