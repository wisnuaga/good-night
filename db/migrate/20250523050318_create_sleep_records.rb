class CreateSleepRecords < ActiveRecord::Migration[7.2]
  def change
    create_table :sleep_records do |t|
      t.references :user, null: false, foreign_key: true
      t.datetime :clock_in, null: false
      t.datetime :clock_out

      t.timestamps
    end

    add_index :sleep_records, [ :user_id, :clock_out ] # for quick lookup of active sleep records by user
  end
end
