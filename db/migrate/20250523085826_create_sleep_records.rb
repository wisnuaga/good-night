class CreateSleepRecords < ActiveRecord::Migration[7.2]
  def change
    create_table :sleep_records do |t|
      t.references :user, null: false, foreign_key: true
      t.datetime :clock_in, null: false
      t.datetime :clock_out
    end

    # Add a partial index on clock_in only for records where clock_out is NULL
    add_index :sleep_records, :clock_in, where: "clock_out IS NULL", name: "index_sleep_records_on_clock_in_where_clock_out_null"
  end
end
