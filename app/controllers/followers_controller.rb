class FollowersController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :set_current_user
  before_action :set_user_to_follow, only: [ :create, :destroy ]

  # POST /users/:id/follow
  def create
    if @current_user.id == @user_to_follow.id
      return render json: { error: "Cannot follow yourself" }, status: :bad_request
    end

    follow = Follower.new(user: @user_to_follow, follower: @current_user)

    if follow.save
      render json: { message: "Followed user successfully" }
    else
      render json: { errors: follow.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /users/:id/unfollow
  def destroy
    follow = Follower.find_by(user: @user_to_follow, follower: @current_user)

    if follow&.destroy
      render json: { message: "Unfollowed user successfully" }
    else
      render json: { error: "Follow relation not found" }, status: :not_found
    end
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
    @user_to_follow = User.find(params[:id])
  end
end
