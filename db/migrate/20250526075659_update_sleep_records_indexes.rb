class UpdateSleepRecordsIndexes < ActiveRecord::Migration[7.2]
  def change
    # Remove old partial index on clock_in where clock_out is NULL
    remove_index :sleep_records, name: "index_sleep_records_on_clock_in_where_clock_out_null"

    # Add composite partial index for active sessions (clock_out IS NULL)
    add_index :sleep_records, [:user_id, :clock_in],
              where: "clock_out IS NULL",
              name: "index_sleep_records_on_user_clock_in_where_clock_out_null"

    # Add composite index for finished sessions (clock_out IS NOT NULL)
    add_index :sleep_records, [:user_id, :clock_in],
              where: "clock_out IS NOT NULL",
              name: "index_sleep_records_on_user_clock_in_where_clock_out_not_null"
  end
end
