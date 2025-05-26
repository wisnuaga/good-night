class SleepRecordController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :set_current_user

  # POST /sleep_records/clock_in
  def clock_in
    result = SleepRecordUsecase::ClockIn.new(current_user).call
    render_result(result: result, status: :created)
  end

  # PUT /sleep_records/clock_out
  def clock_out
    result = SleepRecordUsecase::ClockOut.new(current_user).call
    render_result(result: result, status: :ok)
  end

  # GET /sleep_records
  def index
    result = SleepRecordUsecase::List.new(current_user).call(
      limit: index_params[:limit],
      cursor: index_params[:cursor]
    )

    render_result(result: result, status: :ok)
  end

  private

  def index_params
    permitted = params.permit(:cursor, :limit)

    limit = permitted[:limit].to_i
    limit = Repository::FEED_LIST_LIMIT if limit <= 0

    {
      cursor: permitted[:cursor],
      limit: [ limit, Repository::FEED_LIST_LIMIT ].min
    }
  end
end
