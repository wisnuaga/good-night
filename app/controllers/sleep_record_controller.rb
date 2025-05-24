class SleepRecordController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :set_current_user

  # POST /sleep_records/clock_in
  def clock_in
    result = SleepRecordUsecase::ClockIn.new(@current_user).call
    render_result(result, :created)
  end

  # PUT /sleep_records/clock_out
  def clock_out
    result = SleepRecordUsecase::ClockOut.new(@current_user).call
    render_result(result, :ok)
  end

  def index
    result = SleepRecordUsecase::List.new(
      @current_user,
      include_followers: index_params[:include_followers]
    ).call

    render_result(result, :ok)
  end

  private

  def index_params
    params.permit(:include_followers).tap do |params|
      params[:include_followers] = params[:include_followers] == "true"
    end
  end

  def render_result(result, success_status)
    if result.success?
      render json: result.data, status: success_status
    else
      render json: { error: result.error }, status: :bad_request
    end
  end
end
