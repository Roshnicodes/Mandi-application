class CreateCottonReportingTables < ActiveRecord::Migration[8.1]
  def change
    create_table :cotton_bulletins do |t|
      t.date :report_date, null: false
      t.string :title, null: false
      t.text :notes

      t.timestamps
    end
    add_index :cotton_bulletins, [ :report_date, :title ]

    create_table :cotton_market_observations do |t|
      t.references :cotton_bulletin, null: false, foreign_key: true
      t.string :category, null: false
      t.string :name
      t.decimal :arrival_quantity, precision: 12, scale: 2
      t.decimal :minimum_price, precision: 12, scale: 2
      t.decimal :maximum_price, precision: 12, scale: 2
      t.decimal :modal_price, precision: 12, scale: 2
      t.string :moisture
      t.string :arrival_price
      t.decimal :total_arrival, precision: 12, scale: 2
      t.decimal :traders_buy, precision: 12, scale: 2
      t.decimal :cci_buy, precision: 12, scale: 2
      t.decimal :buy_percentage, precision: 8, scale: 2
      t.text :remarks
      t.integer :position

      t.timestamps
    end
    add_index :cotton_market_observations, [ :cotton_bulletin_id, :category ], name: "index_cotton_observations_on_bulletin_and_category"

    create_table :cotton_seed_rates do |t|
      t.references :cotton_bulletin, null: false, foreign_key: true
      t.string :particular, null: false
      t.string :madhya_pradesh_rate
      t.string :odisha_rate
      t.string :maharashtra_rate
      t.string :reference
      t.integer :position

      t.timestamps
    end

    create_table :candy_rates do |t|
      t.references :cotton_bulletin, null: false, foreign_key: true
      t.string :category, null: false
      t.string :parameter, null: false
      t.string :madhya_pradesh_rate
      t.string :maharashtra_29mm_rate
      t.string :maharashtra_31mm_rate
      t.string :odisha_29mm_rate
      t.string :odisha_30mm_rate
      t.string :reference
      t.integer :position

      t.timestamps
    end
    add_index :candy_rates, [ :cotton_bulletin_id, :category ], name: "index_candy_rates_on_bulletin_and_category"

    create_table :cotton_regional_comparisons do |t|
      t.references :cotton_bulletin, null: false, foreign_key: true
      t.string :line_item, null: false
      t.string :raipur_value
      t.string :ojhar_value
      t.string :kukshi_value
      t.string :pati_value
      t.string :sausar_value
      t.string :jobat_value
      t.string :odisha_value
      t.string :extra_value_one
      t.string :extra_value_two
      t.integer :position

      t.timestamps
    end

    create_table :cotton_call_performances do |t|
      t.references :cotton_bulletin, null: false, foreign_key: true
      t.integer :total_calls, null: false, default: 0
      t.integer :fully_satisfied, null: false, default: 0
      t.decimal :satisfaction_percent, precision: 8, scale: 2
      t.integer :call_again, null: false, default: 0
      t.integer :wrong_call, null: false, default: 0
      t.integer :invalid_exist, null: false, default: 0
      t.integer :position

      t.timestamps
    end
  end
end
