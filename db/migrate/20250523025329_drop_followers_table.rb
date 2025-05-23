class DropFollowersTable < ActiveRecord::Migration[7.2]
  def change
    drop_table :followers
  end
end
