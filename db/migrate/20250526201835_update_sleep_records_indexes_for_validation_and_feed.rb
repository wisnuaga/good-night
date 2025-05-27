class UpdateSleepRecordsIndexesForValidationAndFeed < ActiveRecord::Migration[7.2]
  def change
    # Remove unused indexes if they exist
    if index_exists?(:sleep_records, nil, name: "index_sleep_records_on_user_clock_in_where_clock_out_null")
      remove_index :sleep_records, name: "index_sleep_records_on_user_clock_in_where_clock_out_null"
    end

    if index_exists?(:sleep_records, nil, name: "index_sleep_records_on_user_clock_in_where_clock_out_not_null")
      remove_index :sleep_records, name: "index_sleep_records_on_user_clock_in_where_clock_out_not_null"
    end

    # Add composite partial index to support feed query
    add_index :sleep_records, [:user_id, :clock_in, :sleep_time],
              order: { sleep_time: :desc },
              where: "sleep_time IS NOT NULL",
              name: "index_sleep_records_on_user_clockin_sleeptime_desc",
              if_not_exists: true

    # Add partial index on user_id for active sessions validation
    add_index :sleep_records, :user_id,
              where: "sleep_time IS NULL",
              name: "index_sleep_records_on_user_id_where_sleeptime_null",
              if_not_exists: true
  end
end
