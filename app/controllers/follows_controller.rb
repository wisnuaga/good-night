class FollowsController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :set_current_user
  before_action :set_user_to_follow, only: [ :follow, :unfollow ]

  # PUT /users/:id/follow
  def follow
    if @current_user.id == params[:id].to_i
      render_result(
        OpenStruct.new(success?: false, error: "Cannot follow yourself"),
        :bad_request
      )
      return
    end

    result = FollowUsecase::Follow.new(@current_user, params[:id]).call
    render_result(result, :created)
  end

  # PUT /users/:id/unfollow
  def unfollow
    follow = Follow.find_by(follower_id: @current_user.id, followee_id: @user_to_follow.id)

    if follow.nil?
      render json: { error: "Follow relation not found" }, status: :not_found
      return
    end

    follow.destroy!
    render json: { message: "Unfollowed user successfully" }, status: :ok
  end

  private

  def set_user_to_follow
    @user_to_follow = User.find_by(id: params[:id])
    unless @user_to_follow
      render json: { error: "User to follow not found" }, status: :not_found and return
    end
  end

  def params
    params.permit(:id).to_h.symbolize_keys.merge(user_id: params[:id])
  end
end
