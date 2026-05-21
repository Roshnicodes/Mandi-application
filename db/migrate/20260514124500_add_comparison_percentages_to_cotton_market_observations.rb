class AddComparisonPercentagesToCottonMarketObservations < ActiveRecord::Migration[8.1]
  def change
    add_column :cotton_market_observations, :traders_percentage, :decimal, precision: 8, scale: 2
    add_column :cotton_market_observations, :cci_percentage, :decimal, precision: 8, scale: 2
  end
end
