#!/usr/bin/ruby

require 'nokogiri'
require 'curb'
require 'json'
require 'sqlite3'
require 'sinatra'

class AUC
    def initialize
        @db = SQLite3::Database.new "auc.db"
    end

    def cars
        cars = []
        @car_data.each do |car|
            cars.push(AUC_Car.new(car))
        end
        return cars
    end

end

class AUC_Import < AUC
    def initialize
        url = 'https://usedcars.bmw.co.uk/api/vehicles/list/?body_type=M5-Saloon&distance=300&location=Southampton%2C%20UK&max_supplied_price=40000&model=M%20SERIES&size=100&sort=distance&source=home'
        file = '/home/jim/Downloads/download.json'
        
        results_json = Curl.get(url).body_str
        #data = File.read(file)     
        
        @search_data = JSON.parse(results_json)
        @db = SQLite3::Database.new "auc.db"
    end

    def cars
        cars = []
        @search_data['results'].each do |car|
            cars.push(AUC_Car.new(car))
        end
        return cars
    end

    def records?
        @db.execute("select count(id) from cars")
    end

    def import!
        duplicates = 0
        cars.each do |car|
            duplicate = car.save!
            duplicates += 1 if duplicate
        end
        return cars.length, duplicates
    end
end

class AUC_Archive < AUC
    def initialize
        super()
        @car_data = retrieve
    end

    def retrieve
        search_data = []
        @db.execute("select json from cars").each do |json|
            search_data.push(JSON.parse(json.first))
        end
        
        search_data
    end

    def records?
        @db.execute("select count(id) from cars").first
    end

    def updated_ads
        # list out the adverts which have changed since first post
        @db.execute(
            "select advert_id from cars 
                group by advert_id 
                having count(advert_id) > 1"
        )
    end

    def ads_updated_in_last_day
        ads = updated_ads.join('","')

        @db.execute(
            "select advert_id from cars
            where advert_id in (\"#{ads}\")
            and created_at > datetime('now', '-1 days')"
        )
    end

    def cars_updated_in_last_day
        updated_cars = []

        ads_updated_in_last_day.each do |advert_id|
            get_car_by_advert_id(advert_id.first).each do |ad|
                updated_cars.push(ad)
            end
        end
        
        updated_cars
    end

    def cars_updated
        updated_cars = []

        updated_ads.each do |advert_id|
            get_car_by_advert_id(advert_id.first).each do |ad|
                updated_cars.push(ad)
            end
        end
        
        updated_cars
    end




    def get_car_by_advert_id(advert_id)
        cars = []
        @db.execute(
            "select json from cars
            where advert_id = #{advert_id}"
        ).each do |json|
            cars.push(AUC_Car.new(JSON.parse(json.first)))
        end
        cars
    end

end

class AUC_Car < AUC
    def initialize(data)
        super()
        @car_data = data
    end

    def car_data
        @car_data
    end

    def advert_id
        @car_data['advert_id']
    end

    def registration
        @car_data['registration']['registration']
    end

    def vin
        @car_data['identification']['vin']
    end

    def cash_price
        @car_data['cash_price']['value']
    end

    def mileage
        @car_data['mileage']
    end

    def competition_pack?
        other.include?('Competition package')
    end

    def features
        @car_data['features']
    end

    def additional
        c = {}
        features['additional'].each do |feature|
            c[feature['category']] = [] if c[feature['category']].nil?
            c[feature['category']].push(feature['description'])
        end
        c
    end

    def exterior
        additional['exterior']
    end

    def other
        features['other']['additional'] || []
    end

    def save!
        
        time = Time.now.strftime('%Y-%m-%d %H:%M:%S')
        unless duplicate?
            @db.execute(
                    "insert into cars
                        (               
                            created_at,
                            updated_at,
                            advert_id,
                            reg,
                            price,
                            mileage,
                            json
                        )
                        values 
                        (
                            ?,
                            ?,
                            ?,
                            ?,
                            ?,
                            ?,
                            ?
                        )",
                        [
                            time,
                            time,
                            advert_id,
                            registration,
                            cash_price,
                            mileage,
                            car_data.to_json
                        ]
                )
            return true
        end
        return false
    end
                
    def exists?
        query = @db.execute("select id from cars where advert_id = #{advert_id}")
            return true if query.count > 0
    end

    def duplicate?
        query = @db.execute("select json from cars where advert_id = #{advert_id}").each do |json|
            if @car_data == JSON.parse(json.first)
                return true
            end
        end
        false
    end

end

get '/import' do
    results = AUC_Import.new
    imported, duplicates = results.import!
    records = AUC_Archive.new.records?
    "Imported #{imported} cars, #{duplicates} duplicates, now have #{records.first} records in the archive"
end

get '/' do
    output = []

    results = AUC_Archive.new

    output.push("Competition pack cars:<br><br>")
    results.cars.each do |car|
        if car.competition_pack?
            output.push("id: #{car.advert_id} reg:#{car.registration} £:#{car.cash_price} miles:#{car.mileage} vin:#{car.vin} miles/£:#{car.mileage.to_f/car.cash_price}<br>")
        end
    end

    output.push("<br><br>Updated in last day:<br><br>")
    results.cars_updated_in_last_day.each do |car|
        output.push("id: #{car.advert_id} reg:#{car.registration} £:#{car.cash_price} miles:#{car.mileage} miles/£:#{car.mileage.to_f/car.cash_price}<br>")
    end

    output.push("<br><br>Updated in ever:<br><br>")
    results.cars_updated.each do |car|
        output.push("id: #{car.advert_id} reg:#{car.registration} £:#{car.cash_price} miles:#{car.mileage} miles/£:#{car.mileage.to_f/car.cash_price}<br>")
    end


    output
end