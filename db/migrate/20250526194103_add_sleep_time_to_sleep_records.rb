class AddSleepTimeToSleepRecords < ActiveRecord::Migration[7.2]
  def up
    add_column :sleep_records, :sleep_time, :float

    say_with_time "Backfilling sleep_time (in seconds) for existing sleep_records" do
      SleepRecord.reset_column_information

      SleepRecord.where.not(clock_out: nil).find_each do |record|
        if record.clock_out > record.clock_in
          duration_seconds = record.clock_out - record.clock_in  # difference in seconds (float)
          record.update_column(:sleep_time, duration_seconds)
        else
          record.update_column(:sleep_time, nil)
        end
      end
    end
  end

  def down
    remove_column :sleep_records, :sleep_time
  end
end
