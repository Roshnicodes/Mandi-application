# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
def upsert_state(name)
  State.find_or_create_by!(name: name) do |state|
    state.code = name.to_s.parameterize(separator: " ").split.map { |token| token[0] }.join.first(3).upcase
  end
end

def upsert_district(state, name)
  District.find_or_create_by!(state: state, name: name) do |district|
    district.code = name.to_s.parameterize(separator: " ").split.map { |token| token[0] }.join.first(3).upcase
  end
end

def upsert_market(district, name)
  Market.find_or_create_by!(district: district, name: name)
end

def upsert_group(name, description = nil)
  CommodityGroup.find_or_create_by!(name: name) do |group|
    group.description = description
  end
end

def upsert_commodity(group, name, organic: false)
  Commodity.find_or_create_by!(commodity_group: group, name: name) do |commodity|
    commodity.organic = organic
  end
end

def upsert_variety(commodity, name)
  variety = Variety.where(commodity: commodity).where("LOWER(name) = ?", name.downcase).first
  variety ||= Variety.new(commodity: commodity)
  variety.name = name
  variety.save!
  variety
end

def upsert_grade(commodity, variety, name)
  Grade.find_or_create_by!(commodity: commodity, variety: variety, name: name)
end

pulses = upsert_group("Pulses", "Daily pulses arrivals and price reporting.")
cotton = upsert_group("Cotton", "Cotton mandi and yard reporting.")
organic_cotton = upsert_group("Organic Cotton", "Organic cotton reporting.")

arhar = upsert_commodity(pulses, "Arhar(Tur/Red Gram)(Whole)")
raw_cotton = upsert_commodity(cotton, "Raw Cotton")
upsert_commodity(organic_cotton, "Lokman", organic: true)

arhar_other = upsert_variety(arhar, "Other")
raw_cotton_other = upsert_variety(raw_cotton, "Other")

upsert_grade(arhar, arhar_other, "Non-FAQ")
upsert_grade(arhar, arhar_other, "FAQ")
upsert_grade(raw_cotton, raw_cotton_other, "FAQ")
upsert_grade(raw_cotton, raw_cotton_other, "Non-FAQ")

PriceUnit.find_or_create_by!(name: "Rs./Quintal") do |unit|
  unit.short_name = "Rs./Quintal"
end

ArrivalUnit.find_or_create_by!(name: "Metric Tonnes") do |unit|
  unit.short_name = "MT"
end

ArrivalUnit.find_or_create_by!(name: "Qtl") do |unit|
  unit.short_name = "Qtl"
end

mandi_master = {
  "Madhya Pradesh" => {
    "Betul" => [ "Betul APMC", "Sausar APMC", "Pandurna APMC" ],
    "Ratlam" => [ "Ratlam APMC", "Raoti APMC", "Sailana APMC" ],
    "Alirajpur" => [ "Alirajpur APMC", "Jobat APMC" ],
    "Dhar" => [ "Dhar APMC", "Kukshi APMC", "Dhamnod APMC" ],
    "Barwani" => [ "Barwani APMC", "Anjad APMC" ],
    "Indore" => [ "Indore APMC", "Mhow APMC", "Sanwer APMC" ],
    "Jhabua" => [ "Petlawad APMC" ]
  },
  "Maharashtra" => {
    "Akola" => [ "Akola APMC" ],
    "Nagpur" => [ "Nagpur APMC" ],
    "Amravati" => [ "Amravati APMC", "Daryapur APMC" ],
    "Yavatmal" => [ "Yavatmal APMC", "Pandharkawada APMC" ],
    "Beed" => [ "Beed APMC" ],
    "Jalna" => [ "Jalna APMC" ]
  }
}

mandi_master.each do |state_name, districts|
  state = upsert_state(state_name)

  districts.each do |district_name, market_names|
    district = upsert_district(state, district_name)
    market_names.each { |market_name| upsert_market(district, market_name) }
  end
end

CottonMarketObservation.find_each do |observation|
  next if observation.market_id.present? || observation.name.blank?
  next unless %w[mandi_wise cci_mandi].include?(observation.category)

  canonical_name = observation.name
    .to_s
    .sub(/\s*-\s*DCH\z/i, "")
    .sub(/\s+CCI\z/i, "")
    .squish

  market = Market
    .where("LOWER(name) IN (?)", [ canonical_name.downcase, "#{canonical_name} APMC".downcase ])
    .first

  next if market.blank?

  observation.update!(
    market: market,
    district: market.district,
    state: market.district.state
  )
end
