class AddMadhyaPradesh29mmRateToCandyRates < ActiveRecord::Migration[8.1]
  def change
    add_column :candy_rates, :madhya_pradesh_29mm_rate, :string
  end
end
