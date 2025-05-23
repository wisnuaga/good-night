class CreateFollows < ActiveRecord::Migration[7.2]
  def change
    create_table :follows, id: false do |t|
      t.references :follower, null: false, foreign_key: { to_table: :users }
      t.references :followed, null: false, foreign_key: { to_table: :users }
      t.datetime :created_at, null: false, default: -> { 'CURRENT_TIMESTAMP' }
    end
  end

  add_index :follows, [ :follower_id, :followed_id ], unique: true
end
