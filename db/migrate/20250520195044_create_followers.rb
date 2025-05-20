class CreateFollowers < ActiveRecord::Migration[7.2]
  def change
    create_table :followers do |t|
      t.references :user, null: false, foreign_key: true
      t.references :follower, null: false, foreign_key: true

      t.timestamps
    end

    add_index :followers, [ :user_id, :follower_id ], unique: true
  end
end
