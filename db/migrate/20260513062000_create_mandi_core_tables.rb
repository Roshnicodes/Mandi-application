class CreateMandiCoreTables < ActiveRecord::Migration[8.1]
  def change
    create_table :states do |t|
      t.string :name, null: false
      t.string :code, null: false

      t.timestamps
    end
    add_index :states, :name, unique: true
    add_index :states, :code, unique: true

    create_table :districts do |t|
      t.references :state, null: false, foreign_key: true
      t.string :name, null: false
      t.string :code

      t.timestamps
    end
    add_index :districts, [ :state_id, :name ], unique: true

    create_table :markets do |t|
      t.references :district, null: false, foreign_key: true
      t.string :name, null: false
      t.string :code
      t.string :market_type, null: false, default: "APMC"

      t.timestamps
    end
    add_index :markets, [ :district_id, :name ], unique: true

    create_table :commodity_groups do |t|
      t.string :name, null: false
      t.text :description

      t.timestamps
    end
    add_index :commodity_groups, :name, unique: true

    create_table :commodities do |t|
      t.references :commodity_group, null: false, foreign_key: true
      t.string :name, null: false
      t.boolean :organic, null: false, default: false

      t.timestamps
    end
    add_index :commodities, [ :commodity_group_id, :name ], unique: true

    create_table :varieties do |t|
      t.references :commodity, null: false, foreign_key: true
      t.string :name, null: false

      t.timestamps
    end
    add_index :varieties, [ :commodity_id, :name ], unique: true

    create_table :grades do |t|
      t.references :commodity, null: false, foreign_key: true
      t.references :variety, foreign_key: true
      t.string :name, null: false

      t.timestamps
    end
    add_index :grades, [ :commodity_id, :variety_id, :name ], unique: true

    create_table :price_units do |t|
      t.string :name, null: false
      t.string :short_name

      t.timestamps
    end
    add_index :price_units, :name, unique: true

    create_table :arrival_units do |t|
      t.string :name, null: false
      t.string :short_name

      t.timestamps
    end
    add_index :arrival_units, :name, unique: true

    create_table :daily_price_arrival_reports do |t|
      t.references :state, null: false, foreign_key: true
      t.references :district, null: false, foreign_key: true
      t.references :market, null: false, foreign_key: true
      t.references :commodity_group, null: false, foreign_key: true
      t.references :commodity, null: false, foreign_key: true
      t.references :variety, null: false, foreign_key: true
      t.references :grade, null: false, foreign_key: true
      t.references :price_unit, null: false, foreign_key: true
      t.references :arrival_unit, null: false, foreign_key: true
      t.date :arrival_date, null: false
      t.decimal :min_price, precision: 12, scale: 2, null: false
      t.decimal :max_price, precision: 12, scale: 2, null: false
      t.decimal :modal_price, precision: 12, scale: 2, null: false
      t.decimal :arrival_quantity, precision: 12, scale: 2, null: false
      t.text :remarks

      t.timestamps
    end
    add_index :daily_price_arrival_reports, [ :arrival_date, :market_id, :commodity_id ], name: "index_reports_on_date_market_commodity"
  end
end
