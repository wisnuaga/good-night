class FollowsController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :set_current_user
  before_action :set_user_to_follow, only: [ :create, :destroy ]

  # PUT /users/:id/follow
  def follow
    if @current_user.id == @user_to_follow.id
      return render json: { error: "Cannot follow yourself" }, status: :bad_request
    end

    follow = Follow.new(follower_id: @current_user.id, followed_id: @user_to_follow.id)

    if follow.save
      render json: { message: "Followed user successfully" }, status: :ok
    else
      render json: { errors: follow.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PUT /users/:id/unfollow
  def unfollow
    follow = Follow.find_by(follower_id: @current_user.id, followed_id: @user_to_follow.id)

    if follow.nil?
      render json: { error: "Follow relation not found" }, status: :not_found
      return
    end

    follow.destroy!
    render json: { message: "Unfollowed user successfully" }, status: :ok
  end

  private

  # TODO: Implement a proper authentication mechanism
  def set_current_user
    user_id = request.headers["X-User-Id"]
    unless user_id.present? && User.exists?(user_id)
      render json: { error: "X-User-Id header missing or invalid" }, status: :unauthorized and return
    end
    @current_user = User.find(user_id)
  end

  def set_user_to_follow
    @user_to_follow = User.find_by(id: params[:id])
    unless @user_to_follow
      render json: { error: "User to follow not found" }, status: :not_found and return
    end
  end
end
