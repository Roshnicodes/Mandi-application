class AddObservationDateToCottonMarketObservations < ActiveRecord::Migration[8.1]
  def change
    add_column :cotton_market_observations, :observation_date, :date
    add_index :cotton_market_observations, :observation_date
  end
end
