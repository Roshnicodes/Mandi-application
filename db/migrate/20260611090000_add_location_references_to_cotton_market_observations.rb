class AddLocationReferencesToCottonMarketObservations < ActiveRecord::Migration[8.1]
  def change
    add_reference :cotton_market_observations, :state, foreign_key: true
    add_reference :cotton_market_observations, :district, foreign_key: true
    add_reference :cotton_market_observations, :market, foreign_key: true
  end
end
