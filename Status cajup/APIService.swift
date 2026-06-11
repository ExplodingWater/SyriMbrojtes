//
//  APIService.swift
//  Status cajup
//
//  Calls Open-Meteo directly — no backend required.
//  Tirana / Gjimnazi Andon Zako Çajupi: lat 41.3372, lon 19.8328
//

import Foundation
import CoreLocation

// MARK: - Private Open-Meteo response shapes

private struct OMWeatherResponse: Decodable {
    let current: OMCurrent
    let hourly: OMHourly
    let daily: OMDaily
}

private struct OMCurrent: Decodable {
    let time: String
    let temperature2m: Double
    let relativeHumidity2m: Int
    let apparentTemperature: Double
    let precipitation: Double
    let rain: Double
    let windSpeed10m: Double
    let windDirection10m: Double
    let windGusts10m: Double
    let weatherCode: Int

    enum CodingKeys: String, CodingKey {
        case time
        case temperature2m        = "temperature_2m"
        case relativeHumidity2m   = "relative_humidity_2m"
        case apparentTemperature  = "apparent_temperature"
        case precipitation, rain
        case windSpeed10m         = "wind_speed_10m"
        case windDirection10m     = "wind_direction_10m"
        case windGusts10m         = "wind_gusts_10m"
        case weatherCode          = "weather_code"
    }
}

private struct OMHourly: Decodable {
    let precipitationProbability: [Int]
    let precipitation: [Double]

    enum CodingKeys: String, CodingKey {
        case precipitationProbability = "precipitation_probability"
        case precipitation
    }
}

private struct OMDaily: Decodable {
    let time: [String]
    let precipitationSum: [Double]
    let precipitationProbabilityMax: [Int]
    let windSpeed10mMax: [Double]

    enum CodingKeys: String, CodingKey {
        case time
        case precipitationSum              = "precipitation_sum"
        case precipitationProbabilityMax   = "precipitation_probability_max"
        case windSpeed10mMax               = "wind_speed_10m_max"
    }
}

private struct OMAQResponse: Decodable {
    let current: OMAQCurrent
}

private struct OMAQCurrent: Decodable {
    let pm25: Double
    let pm10: Double
    let europeanAqi: Int

    enum CodingKeys: String, CodingKey {
        case pm25        = "pm2_5"
        case pm10
        case europeanAqi = "european_aqi"
    }
}

// MARK: - Private USGS response shapes

private struct USGSEqResponse: Decodable {
    let features: [USGSEqFeature]
}

private struct USGSEqFeature: Decodable {
    let id: String
    let properties: USGSEqProperties
    let geometry: USGSEqGeometry
}

private struct USGSEqProperties: Decodable {
    let mag: Double?
    let place: String?
    let time: Int64?
    let url: String?
    let title: String?
}

private struct USGSEqGeometry: Decodable {
    let coordinates: [Double]
}

// MARK: - Service

enum APIService {
    private static let lat = 41.3372
    private static let lon = 19.8328

    static func fetchStats() async throws -> EnvironmentData {
        // Fire requests in parallel
        async let weather = fetchWeather()
        async let aq      = fetchAirQuality()
        async let eq      = fetchEarthquakes()
        
        let w = try await weather
        let a = try await aq
        let e = await eq
        
        return try buildEnvironmentData(weather: w, aq: a, eq: e)
    }

    // MARK: Network calls

    private static func fetchEarthquakes() async -> USGSEqResponse {
        let urlString =
            "https://earthquake.usgs.gov/fdsnws/event/1/query" +
            "?format=geojson&latitude=\(lat)&longitude=\(lon)" +
            "&maxradiuskm=400&minmagnitude=3.0&limit=10"
        
        guard let url = URL(string: urlString) else { return USGSEqResponse(features: []) }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return try JSONDecoder().decode(USGSEqResponse.self, from: data)
        } catch {
            print("Failed to fetch earthquakes, continuing with empty data: \(error)")
            return USGSEqResponse(features: [])
        }
    }

    private static func fetchWeather() async throws -> OMWeatherResponse {
        let urlString =
            "https://api.open-meteo.com/v1/forecast" +
            "?latitude=\(lat)&longitude=\(lon)" +
            "&current=temperature_2m,relative_humidity_2m,apparent_temperature" +
            ",precipitation,rain,wind_speed_10m,wind_direction_10m,wind_gusts_10m,weather_code" +
            "&hourly=precipitation_probability,precipitation" +
            "&daily=precipitation_sum,precipitation_probability_max,wind_speed_10m_max" +
            "&timezone=Europe%2FTirane&forecast_days=3"

        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(OMWeatherResponse.self, from: data)
    }

    private static func fetchAirQuality() async throws -> OMAQResponse {
        let urlString =
            "https://air-quality-api.open-meteo.com/v1/air-quality" +
            "?latitude=\(lat)&longitude=\(lon)" +
            "&current=pm2_5,pm10,european_aqi" +
            "&timezone=Europe%2FTirane"

        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(OMAQResponse.self, from: data)
    }

    // MARK: Build EnvironmentData

    private static func buildEnvironmentData(
        weather: OMWeatherResponse,
        aq: OMAQResponse,
        eq: USGSEqResponse
    ) throws -> EnvironmentData {

        let cur    = weather.current
        let hourly = weather.hourly
        let daily  = weather.daily

        // --- Rain stats for next 24 h ---
        let probs24     = Array(hourly.precipitationProbability.prefix(24))
        let precip24    = Array(hourly.precipitation.prefix(24))
        let maxProb     = Double(probs24.max() ?? 0)
        let totalRain   = precip24.reduce(0.0, +)
        let rainHour    = precip24.firstIndex(where: { $0 > 0.1 })

        // --- Daily forecast rows ---
        let forecastDays: [DayForecast] = daily.time.indices.map { i in
            DayForecast(
                date:             daily.time[i],
                precipitationMm:  daily.precipitationSum[safe: i]            ?? 0,
                probabilityPct:   daily.precipitationProbabilityMax[safe: i] ?? 0,
                maxWindKph:       daily.windSpeed10mMax[safe: i]              ?? 0
            )
        }

        // --- Process Earthquakes ---
        var eqEvents: [EarthquakeEvent] = []
        for feat in eq.features {
            let id = feat.id
            let magnitude = feat.properties.mag ?? 0.0
            let place = feat.properties.place ?? "Lokacion i panjohur"
            let time = feat.properties.time ?? 0
            
            guard feat.geometry.coordinates.count >= 2 else { continue }
            let lon = feat.geometry.coordinates[0]
            let lat = feat.geometry.coordinates[1]
            let depth = feat.geometry.coordinates.count >= 3 ? feat.geometry.coordinates[2] : 0.0
            
            let schoolLoc = CLLocation(latitude: APIService.lat, longitude: APIService.lon)
            let eqLoc = CLLocation(latitude: lat, longitude: lon)
            let distance = schoolLoc.distance(from: eqLoc) / 1000.0
            
            // felt circle math
            let feltRadius = exp((magnitude / 1.01) - 0.13)
            let notifyRadius = 0.4 * feltRadius
            
            let isFelt = distance <= feltRadius
            let isDeep = distance <= notifyRadius
            
            let event = EarthquakeEvent(
                id: id,
                magnitude: magnitude,
                place: place,
                time: time,
                latitude: lat,
                longitude: lon,
                distance: distance,
                depth: depth,
                isFelt: isFelt,
                isDeep: isDeep
            )
            eqEvents.append(event)
        }
        eqEvents.sort { $0.time > $1.time }

        // --- Assemble model ---
        let aqi = aq.current.europeanAqi

        return EnvironmentData(
            location: "Gjimnazi Andon Zako Çajupi, Tiranë",
            updated:  cur.time,
            current: CurrentConditions(
                temperature:  cur.temperature2m,
                feelsLike:    cur.apparentTemperature,
                humidity:     cur.relativeHumidity2m,
                rain:         cur.rain,
                precipitation: cur.precipitation,
                windSpeed:    cur.windSpeed10m,
                windGusts:    cur.windGusts10m,
                windDirection: Int(cur.windDirection10m.rounded()),
                weatherCode:  cur.weatherCode
            ),
            rain: RainInfo(
                probabilityNext24h: maxProb,
                totalMmNext24h:     (totalRain * 10).rounded() / 10,
                nextRainInHours:    rainHour,
                dailyForecast:      forecastDays
            ),
            airQuality: AirQuality(
                europeanAqi: aqi,
                pm2_5:       aq.current.pm25,
                pm10:        aq.current.pm10,
                label:       aqiLabel(aqi)
            ),
            disasters: Disasters(
                flood: floodRisk(precip: cur.precipitation, total24h: totalRain, prob: maxProb),
                fire:  fireRisk(temp: cur.temperature2m, humidity: cur.relativeHumidity2m, wind: cur.windSpeed10m)
            ),
            earthquakes: eqEvents
        )
    }

    // MARK: Risk scoring

    private static func floodRisk(precip: Double, total24h: Double, prob: Double) -> DisasterRisk {
        var score = 0
        score += precip > 2 ? 2 : (precip > 0 ? 1 : 0)
        score += total24h > 20 ? 3 : (total24h > 10 ? 2 : (total24h > 3 ? 1 : 0))
        score += prob > 70 ? 2 : (prob > 40 ? 1 : 0)
        switch score {
        case 5...: return DisasterRisk(level: "I lartë",     description: "Priten reshje të dendura shiu. Mundësi për përmbytje lokale.")
        case 3...: return DisasterRisk(level: "Mesatar", description: "Reshje të shtuara shiu. Monitoroni zonat e kullimit.")
        case 1...: return DisasterRisk(level: "I ulët",      description: "Priten pak reshje shiu. Rrezik i ulët përmbytjeje.")
        default:   return DisasterRisk(level: "Minimal",  description: "Kushte të thata. Nuk ka rrezik përmbytjeje.")
        }
    }

    private static func fireRisk(temp: Double, humidity: Int, wind: Double) -> DisasterRisk {
        var score = 0
        score += temp > 35 ? 3 : (temp > 28 ? 2 : (temp > 20 ? 1 : 0))
        score += humidity < 20 ? 3 : (humidity < 35 ? 2 : (humidity < 50 ? 1 : 0))
        score += wind > 40 ? 2 : (wind > 20 ? 1 : 0)
        switch score {
        case 6...: return DisasterRisk(level: "Ekstrem",  description: "Rrezik ekstrem zjarri. Shmangni flakët e hapura.")
        case 4...: return DisasterRisk(level: "I lartë",     description: "Rrezik i lartë zjarri. Kushte të thata dhe me erë.")
        case 2...: return DisasterRisk(level: "Mesatar", description: "Rrezik mesatar zjarri. Të tregohet kujdes jashtë.")
        default:   return DisasterRisk(level: "I ulët",      description: "Rrezik i ulët zjarri. Kushtet nuk favorizojnë zjarret.")
        }
    }

    private static func aqiLabel(_ aqi: Int) -> String {
        switch aqi {
        case ...20:  return "Shkëlqyeshëm"
        case ...40:  return "E pranueshme"
        case ...60:  return "Mesatare"
        case ...80:  return "Dobët"
        case ...100: return "Shumë dobët"
        default:     return "Jashtëzakonisht dobët"
        }
    }
}

// MARK: - Safe array subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
