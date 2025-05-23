class AddIdToFollows < ActiveRecord::Migration[7.2]
  def change
    add_column :follows, :id, :primary_key
  end
end
