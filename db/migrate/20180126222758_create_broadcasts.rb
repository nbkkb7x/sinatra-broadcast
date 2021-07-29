class CreateBroadcasts < ActiveRecord::Migration[5.1]
  def change
    create_table :broadcasts do |t|
      t.string :from, :default => '+15558675309'
      t.string :subject
      t.text :body
      t.boolean :broadcast, :default => false
      t.timestamps
    end
  end
end
