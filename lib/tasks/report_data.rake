namespace :reports do
  desc "Permanently clear Daily Mandi Report and Cotton Bulletin data, including attached files"
  task clear_report_data: :environment do
    models_with_attachments = [
      DailyPriceArrivalReport,
      CottonBulletin,
      CottonMarketObservation,
      CottonSeedRate,
      CandyRate,
      CottonRegionalComparison,
      CottonCallPerformance
    ]

    counts = models_with_attachments.to_h { |model| [ model.name, model.count ] }

    models_with_attachments.each do |model|
      model.find_each do |record|
        record.attachments.each(&:purge)
      end
    end

    DailyPriceArrivalReport.destroy_all
    CottonBulletin.destroy_all

    remaining = models_with_attachments.to_h { |model| [ model.name, model.count ] }
    puts "Removed report data: #{counts.inspect}"
    puts "Remaining report data: #{remaining.inspect}"
  end
end
