class SleepRecordController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :set_current_user

  # POST /sleep_records/clock_in
  def clock_in
    # Check if an active session exists
    active_session = @current_user.sleep_records.find_by(clock_out: nil)
    if active_session
      render json: { error: "You already have an active sleep session" }, status: :bad_request and return
    end

    sleep_record = @current_user.sleep_records.new(clock_in: Time.current)
    if sleep_record.save
      render json: sleep_record, status: :created
    else
      render json: { errors: sleep_record.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PUT /sleep_records/clock_out
  def clock_out
    sleep_record = @current_user.sleep_records.where(clock_out: nil).order(:clock_in).last
    if sleep_record.nil?
      return render json: { error: "No active sleep session found" }, status: :not_found
    end

    sleep_record.clock_out = Time.current
    if sleep_record.save
      render json: sleep_record, status: :ok
    else
      render json: { errors: sleep_record.errors.full_messages }, status: :unprocessable_entity
    end
  end
end
