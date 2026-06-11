//
//  EnvironmentData.swift
//  Status cajup
//

import Foundation

// MARK: - Top-level response

struct EnvironmentData: Decodable {
    let location: String
    let updated: String
    let current: CurrentConditions
    let rain: RainInfo
    let airQuality: AirQuality
    let disasters: Disasters
    let earthquakes: [EarthquakeEvent]
}

struct CurrentConditions: Decodable {
    let temperature: Double
    let feelsLike: Double
    let humidity: Int
    let rain: Double
    let precipitation: Double
    let windSpeed: Double
    let windGusts: Double
    let windDirection: Int
    let weatherCode: Int
}

struct RainInfo: Decodable {
    let probabilityNext24h: Double
    let totalMmNext24h: Double
    let nextRainInHours: Int?
    let dailyForecast: [DayForecast]
}

struct DayForecast: Decodable, Identifiable {
    let date: String
    let precipitationMm: Double
    let probabilityPct: Int
    let maxWindKph: Double

    var id: String { date }

    var shortDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let d = formatter.date(from: date) else { return date }
        let out = DateFormatter()
        out.locale = Locale(identifier: "sq_AL")
        out.dateFormat = "EEE, d MMM"
        return out.string(from: d)
    }
}

struct AirQuality: Decodable {
    let europeanAqi: Int
    let pm2_5: Double
    let pm10: Double
    let label: String
}

struct Disasters: Decodable {
    let flood: DisasterRisk
    let fire: DisasterRisk
}

struct DisasterRisk: Decodable {
    let level: String
    let description: String

    var color: String {
        switch level {
        case "Minimal", "Low", "I ulët": return "green"
        case "Moderate", "Mesatar": return "yellow"
        case "High", "I lartë": return "orange"
        default: return "red" // Ekstrem
        }
    }

    var icon: String {
        switch level {
        case "Minimal", "Low", "I ulët": return "checkmark.shield"
        case "Moderate", "Mesatar": return "exclamationmark.triangle"
        case "High", "I lartë": return "exclamationmark.triangle.fill"
        default: return "xmark.shield.fill" // Ekstrem
        }
    }
}

struct EarthquakeEvent: Decodable, Identifiable {
    let id: String
    let magnitude: Double
    let place: String
    let time: Int64
    let latitude: Double
    let longitude: Double
    let distance: Double
    let depth: Double
    let isFelt: Bool
    let isDeep: Bool
}
