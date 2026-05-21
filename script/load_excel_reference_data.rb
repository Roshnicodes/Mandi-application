puts "Loading Excel reference data..."

def upsert_by_name(scope, attrs)
  record = scope.find_or_initialize_by(name: attrs.fetch(:name))
  record.assign_attributes(attrs)
  record.save!
  record
end

maharashtra = upsert_by_name(State.all, name: "Maharashtra")
upsert_by_name(State.all, name: "Madhya Pradesh")
upsert_by_name(State.all, name: "Odisha")

akola = District.find_or_initialize_by(state: maharashtra, name: "Akola")
akola.save!
nagpur = District.find_or_initialize_by(state: maharashtra, name: "Nagpur")
nagpur.save!

akola_market = Market.find_or_initialize_by(district: akola, name: "Akola APMC")
akola_market.save!
nagpur_market = Market.find_or_initialize_by(district: nagpur, name: "Nagpur APMC")
nagpur_market.save!

pulses = CommodityGroup.find_or_create_by!(name: "Pulses")
cotton = CommodityGroup.find_or_create_by!(name: "Cotton")
CommodityGroup.find_or_create_by!(name: "Organic Cotton")

arhar = Commodity.find_or_initialize_by(commodity_group: pulses, name: "Arhar(Tur/Red Gram)(Whole)")
arhar.organic = false
arhar.save!

raw_cotton = Commodity.find_or_initialize_by(commodity_group: cotton, name: "Raw Cotton")
raw_cotton.organic = false
raw_cotton.save!

arhar_other = Variety.find_or_create_by!(commodity: arhar, name: "Other")
Variety.find_or_create_by!(commodity: raw_cotton, name: "other")

arhar_faq = Grade.find_or_create_by!(commodity: arhar, variety: arhar_other, name: "FAQ")
arhar_non_faq = Grade.find_or_create_by!(commodity: arhar, variety: arhar_other, name: "Non-FAQ")

price_unit = PriceUnit.find_or_initialize_by(name: "Rs./Quintal")
price_unit.short_name = "Rs./Quintal"
price_unit.save!

metric_tonnes = ArrivalUnit.find_or_initialize_by(name: "Metric Tonnes")
metric_tonnes.short_name = "MT"
metric_tonnes.save!

ArrivalUnit.find_or_create_by!(name: "Qtl") do |unit|
  unit.short_name = "Qtl"
end

daily_rows = [
  [ akola_market, arhar_faq, Date.new(2026, 2, 18), 8000, 8180, 8090, 120.00 ],
  [ akola_market, arhar_non_faq, Date.new(2026, 2, 18), 7000, 7995, 7500, 169.60 ],
  [ akola_market, arhar_non_faq, Date.new(2026, 2, 17), 7000, 7975, 7600, 421.60 ],
  [ akola_market, arhar_non_faq, Date.new(2026, 2, 16), 7000, 7980, 7905, 198.50 ],
  [ nagpur_market, arhar_non_faq, Date.new(2026, 2, 18), 7000, 7880, 7660, 666.60 ],
  [ nagpur_market, arhar_non_faq, Date.new(2026, 2, 16), 7400, 7999, 7850, 401.80 ]
]

daily_rows.each do |market, grade, arrival_date, min_price, max_price, modal_price, arrival_quantity|
  report = DailyPriceArrivalReport.find_or_initialize_by(
    market: market,
    commodity: arhar,
    variety: arhar_other,
    grade: grade,
    arrival_date: arrival_date,
    min_price: min_price,
    max_price: max_price,
    modal_price: modal_price,
    arrival_quantity: arrival_quantity
  )
  report.state = market.district.state
  report.district = market.district
  report.commodity_group = pulses
  report.price_unit = price_unit
  report.arrival_unit = metric_tonnes
  report.remarks = "Imported from Excel reference"
  report.save!
end

bulletin = CottonBulletin.where(title: "Raw Cotton Rate").order(:id).first_or_initialize
bulletin.report_date = Date.new(2025, 11, 28)
bulletin.notes = "Imported from Excel reference"
bulletin.save!

def upsert_observation(bulletin, category, name, attrs)
  scope = bulletin.cotton_market_observations.where(category: category)
  record =
    if name.present?
      scope.find_or_initialize_by(name: name)
    else
      scope.find_or_initialize_by(position: attrs[:position])
    end

  record.assign_attributes(attrs.merge(category: category, name: name))
  record.save!
end

[
  [ "Kukshi", 1, 1028, 3500, 7060, 6895, "Krishi Upaj Mandi - Kukshi" ],
  [ "Anjad", 2, 1032, 4410, 7110, 6000, "Krishi Upaj Mandi - Anjad" ],
  [ "Dhamnod", 3, 1881, 5325, 7000, 6575, "Krishi Upaj Mandi - Dhamnod" ],
  [ "Sausar", 4, 1400, 6900, 8010, 7010, "Krishi Upaj Mandi - Sausar" ],
  [ "Ratlam - DCH", 5, nil, nil, nil, nil, "Krishi Upaj Mandi - Ratlam" ],
  [ "Petlawad (Bamnia) - DCH", 6, nil, nil, nil, nil, "Krishi Upaj Mandi - Petlawad" ]
].each do |name, position, qty, min_price, max_price, modal_price, remarks|
  upsert_observation(
    bulletin,
    "mandi_wise",
    name,
    position: position,
    arrival_quantity: qty,
    minimum_price: min_price,
    maximum_price: max_price,
    modal_price: modal_price,
    moisture: nil,
    arrival_price: nil,
    total_arrival: nil,
    traders_buy: nil,
    traders_percentage: nil,
    cci_buy: nil,
    cci_percentage: nil,
    buy_percentage: nil,
    observation_date: nil,
    remarks: remarks
  )
end

[
  [ "Anjad CCI", 1, 2691, 7689, 8010, 7929, "Krishi Upaj Mandi - Anjad CCI" ],
  [ "Kukshi CCI", 2, 3798, 7689, 8010, 8010, "Krishi Upaj Mandi - Kukshi CCI" ]
].each do |name, position, qty, min_price, max_price, modal_price, remarks|
  upsert_observation(
    bulletin,
    "cci_mandi",
    name,
    position: position,
    arrival_quantity: qty,
    minimum_price: min_price,
    maximum_price: max_price,
    modal_price: modal_price,
    moisture: nil,
    arrival_price: nil,
    total_arrival: nil,
    traders_buy: nil,
    traders_percentage: nil,
    cci_buy: nil,
    cci_percentage: nil,
    buy_percentage: nil,
    observation_date: nil,
    remarks: remarks
  )
end

[
  [ "K M Anjad", 1, 225, "13% to 15%", "6900 - 7000", nil ],
  [ "TDN", 2, 25, "12% to 15%", "6850 - 7000", nil ],
  [ "SGI (Sausar)", 3, 125, "18% to 21%", "6900 - 7050", nil ],
  [ "Elkay GIN (Ratlam) - DCH", 4, nil, "18% to 22%", "7600 - 7900", nil ],
  [ "Mahesh Seth (Thandla)", 5, nil, "20", "7700 - 7800", "16, 20, 25" ]
].each do |name, position, qty, moisture, arrival_price, remarks|
  upsert_observation(
    bulletin,
    "gin_wise",
    name,
    position: position,
    arrival_quantity: qty,
    minimum_price: nil,
    maximum_price: nil,
    modal_price: nil,
    moisture: moisture,
    arrival_price: arrival_price,
    total_arrival: nil,
    traders_buy: nil,
    traders_percentage: nil,
    cci_buy: nil,
    cci_percentage: nil,
    buy_percentage: nil,
    observation_date: nil,
    remarks: remarks
  )
end

[
  [ Date.new(2025, 11, 15), 1, 2250, 820, 36, 1430, 64 ],
  [ Date.new(2025, 11, 18), 2, 1854, 604, 33, 1250, 67 ],
  [ Date.new(2025, 11, 19), 3, 2163, 273, 13, 1890, 87 ],
  [ Date.new(2025, 11, 20), 4, 2677, 719, 27, 1958, 73 ],
  [ Date.new(2025, 11, 21), 5, 2710, 342, 13, 2368, 87 ]
].each do |observation_date, position, total_arrival, traders_buy, traders_percentage, cci_buy, cci_percentage|
  upsert_observation(
    bulletin,
    "comparison_sheet",
    nil,
    position: position,
    arrival_quantity: nil,
    minimum_price: nil,
    maximum_price: nil,
    modal_price: nil,
    moisture: nil,
    arrival_price: nil,
    total_arrival: total_arrival,
    traders_buy: traders_buy,
    traders_percentage: traders_percentage,
    cci_buy: cci_buy,
    cci_percentage: cci_percentage,
    buy_percentage: cci_percentage,
    observation_date: observation_date,
    remarks: nil
  )
end

seed_rate = bulletin.cotton_seed_rates.find_or_initialize_by(particular: "Kakda")
seed_rate.assign_attributes(
  position: 1,
  madhya_pradesh_rate: "3300-3450",
  odisha_rate: nil,
  maharashtra_rate: nil,
  reference: "Smart Info"
)
seed_rate.save!

[
  [ "mch", "RD - 70", 1, "-", "-", "-", "-", "-", "Smart Info" ],
  [ "mch", "RD - 72", 2, "49000-49200", "-", "-", "-", "-", "Smart Info" ],
  [ "mch", "RD - 73", 3, "50000-50200", "-", "-", "-", "-", "Smart Info" ],
  [ "mch", "RD - 74", 4, "50800-51000", "-", "-", "-", "-", "Smart Info" ],
  [ "mch", "RD - 75", 5, "51300-51500", "-", "-", "-", "-", "Smart Info" ],
  [ "dch", "DCH - 33-35 MM", 1, "70000-72500", "-", "-", "-", "-", "MM Service Wise" ]
].each do |category, parameter, position, mp, mh29, mh31, od29, od30, reference|
  rate = bulletin.candy_rates.find_or_initialize_by(category: category, parameter: parameter)
  rate.assign_attributes(
    position: position,
    madhya_pradesh_rate: mp,
    maharashtra_29mm_rate: mh29,
    maharashtra_31mm_rate: mh31,
    odisha_29mm_rate: od29,
    odisha_30mm_rate: od30,
    reference: reference
  )
  rate.save!
end

[
  [ "OC Cotton", 1, "6850.00", "6850.00", "6850.00", "6850.00", "6850.00", "6950.00", "6950.00", "6950", nil ],
  [ "Bonus", 2, "300.00", "300.00", "300.00", "300.00", "300.00", "300.00", "250.00", "250", nil ],
  [ "Total", 3, "7150.00", "7150.00", "7150.00", "7150.00", "7150.00", "7250.00", "7200.00", "7200", nil ],
  [ "Moisture %", 4, "12 to 15", "12 to 15", "12 to 15", "12 to 15", "16 to 18", "12 to 15", "20 to 22", nil, nil ]
].each do |line_item, position, raipur, ojhar, kukshi, pati, sausar, jobat, odisha, extra1, extra2|
  comparison = bulletin.cotton_regional_comparisons.find_or_initialize_by(line_item: line_item)
  comparison.assign_attributes(
    position: position,
    raipur_value: raipur,
    ojhar_value: ojhar,
    kukshi_value: kukshi,
    pati_value: pati,
    sausar_value: sausar,
    jobat_value: jobat,
    odisha_value: odisha,
    extra_value_one: extra1,
    extra_value_two: extra2
  )
  comparison.save!
end

[
  [ 1, 26, 15, 14, 5, 0 ],
  [ 2, 38, 20, 13, 5, 0 ],
  [ 3, 30, 24, 4, 0, 0 ],
  [ 4, 31, 22, 7, 0, 0 ],
  [ 5, 125, 81, 38, 10, 0 ]
].each do |position, total_calls, fully_satisfied, call_again, wrong_call, invalid_exist|
  row = bulletin.cotton_call_performances.find_or_initialize_by(position: position)
  row.assign_attributes(
    total_calls: total_calls,
    fully_satisfied: fully_satisfied,
    call_again: call_again,
    wrong_call: wrong_call,
    invalid_exist: invalid_exist
  )
  row.save!
end

{
  "mandi_wise" => {
    "Kukshi" => 1,
    "Anjad" => 2,
    "Dhamnod" => 3,
    "Sausar" => 4,
    "Ratlam - DCH" => 5,
    "Petlawad (Bamnia) - DCH" => 6
  },
  "cci_mandi" => {
    "Anjad CCI" => 1,
    "Kukshi CCI" => 2
  },
  "gin_wise" => {
    "K M Anjad" => 1,
    "TDN" => 2,
    "SGI (Sausar)" => 3,
    "Elkay GIN (Ratlam) - DCH" => 4,
    "Mahesh Seth (Thandla)" => 5
  },
  "tdn_moisture" => {
    "Kukshi" => 1
  }
}.each do |category, expected_names|
  rows = bulletin.cotton_market_observations.where(category: category).order(:id).to_a
  keep_ids = expected_names.map do |name, position|
    rows.find { |row| row.name == name && row.position == position }&.id
  end.compact

  bulletin.cotton_market_observations.where(category: category).where.not(id: keep_ids).destroy_all
end

expected_comparison_positions = [ 1, 2, 3, 4, 5 ]
bulletin.cotton_market_observations.where(category: "comparison_sheet").where.not(position: expected_comparison_positions).destroy_all

expected_seed_particulars = [ "Kakda" ]
bulletin.cotton_seed_rates.where.not(particular: expected_seed_particulars).destroy_all

expected_candy_pairs = [
  [ "mch", "RD - 70" ],
  [ "mch", "RD - 72" ],
  [ "mch", "RD - 73" ],
  [ "mch", "RD - 74" ],
  [ "mch", "RD - 75" ],
  [ "dch", "DCH - 33-35 MM" ]
]
bulletin.candy_rates.find_each do |row|
  row.destroy! unless expected_candy_pairs.include?([ row.category, row.parameter ])
end

expected_regional_items = [ "OC Cotton", "Bonus", "Total", "Moisture %" ]
bulletin.cotton_regional_comparisons.where.not(line_item: expected_regional_items).destroy_all

expected_call_positions = [ 1, 2, 3, 4, 5 ]
bulletin.cotton_call_performances.where.not(position: expected_call_positions).destroy_all

puts "Reference data loaded successfully."
