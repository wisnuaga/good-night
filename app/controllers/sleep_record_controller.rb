class SleepRecordController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :set_current_user

  # POST /sleep_records/clock_in
  def clock_in
    result = SleepRecordUsecase::ClockIn.new(@current_user).call
    if result.success?
      render json: result.data, status: :created
    else
      render json: { error: result.error }, status: :bad_request
    end
  end

  # PUT /sleep_records/clock_out
  def clock_out
    result = SleepRecordUsecase::ClockOut.new(@current_user).call
    if result.success?
      render json: result.data, status: :ok
    else
      render json: { error: result.error }, status: :bad_request
    end
  end

  def index
    follower_ids = @current_user.active_follows.pluck(:followed_id)
    follower_ids << @current_user.id # Include self
    sleep_records = SleepRecord.where(user_id: follower_ids).order(clock_in: :desc)

    render json: sleep_records, status: :ok
  end
end
