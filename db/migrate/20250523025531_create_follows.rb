class CreateFollows < ActiveRecord::Migration[7.2]
  def change
    create_table :follows, id: false do |t|
      t.references :follower, null: false, foreign_key: { to_table: :users }
      t.references :followed, null: false, foreign_key: { to_table: :users }
    end
  end
end
