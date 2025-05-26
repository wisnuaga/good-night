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
    result = SleepRecordUsecase::List.new(current_user).call(
      cursor: index_params[:cursor],
      limit: index_params[:limit]
    )

    render_result(result, :ok)
  end

  private

  def index_params
    permitted = params.permit(:cursor, :limit)

    # Validate and normalize limit param
    limit = permitted[:limit].to_i
    if limit <= 0
      limit = SleepRecordUsecase::List::DEFAULT_LIMIT
    end

    permitted[:limit] = limit
    permitted
  end
end
