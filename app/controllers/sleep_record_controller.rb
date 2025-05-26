class SleepRecordController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :set_current_user

  # POST /sleep_records/clock_in
  def clock_in
    result = SleepRecordUsecase::ClockIn.new(current_user).call
    render_result(result, :created)
  end

  # PUT /sleep_records/clock_out
  def clock_out
    result = SleepRecordUsecase::ClockOut.new(current_user).call
    render_result(result, :ok)
  end

  # GET /sleep_records
  def index
    result = SleepRecordUsecase::List.new(
      current_user
    ).call(
      cursor: params[:cursor],
      limit: params[:limit]&.to_i.presence || SleepRecordUsecase::List::DEFAULT_LIMIT
    )

    render_result(result, :ok)
  end

  private

  def index_params
    params.permit(:include_followees).tap do |params|
      params[:include_followees] = params[:include_followees] == "true"
    end
  end
end
