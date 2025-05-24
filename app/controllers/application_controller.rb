class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  private

  # TODO: Implement a proper authentication mechanism
  def set_current_user
    user_id = request.headers["X-User-Id"]
    render json: { error: "X-User-Id header missing" }, status: :unauthorized and return unless user_id.present?

    @current_user = User.find_by(id: user_id)
    render json: { error: "Current user not found" }, status: :unauthorized and return if @current_user.nil?
  end
end
