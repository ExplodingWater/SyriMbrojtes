//
//  NotificationManager.swift
//  Status cajup
//
//  Created by Martin Hafizi on 10.6.26.
//

import Foundation
import UserNotifications
import BackgroundTasks

enum NotificationManager {
    static let refreshTaskId = "Martin.Status-cajup.refresh"

    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            } else {
                print("Notification permission granted: \(granted)")
            }
        }
    }

    static func triggerNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to dispatch notification: \(error)")
            }
        }
    }

    static func checkAndTriggerNotifications(data: EnvironmentData) {
        let defaults = UserDefaults.standard
        let lastFloodLevel = defaults.string(forKey: "last_flood_level") ?? ""
        let lastFireLevel = defaults.string(forKey: "last_fire_level") ?? ""
        
        let currentFlood = data.disasters.flood.level
        let currentFire = data.disasters.fire.level
        
        let floodActiveNotified = defaults.bool(forKey: "flood_active_notified")
        let fireActiveNotified = defaults.bool(forKey: "fire_active_notified")

        // 1. Flood threat level and active checks
        if currentFlood == "I lartë" {
            if lastFloodLevel != "I lartë" {
                triggerNotification(
                    title: "⚠️ Rrezik Përmbytjeje i Lartë",
                    body: "Reshje shumë të dendura shiu parashikohen pranë Çajupit. Mundësi për përmbytje lokale."
                )
                defaults.set("I lartë", forKey: "last_flood_level")
            }
            
            // If precipitation is heavy, a flood is "actually happening"
            if data.current.precipitation >= 10.0 {
                if !floodActiveNotified {
                    triggerNotification(
                        title: "🚨 EMERGJENCË: PËRMBYTJE",
                        body: "Përmbytje po ndodh! Intensiteti i reshjeve aktualisht: \(String(format: "%.1f", data.current.precipitation)) mm."
                    )
                    defaults.set(true, forKey: "flood_active_notified")
                }
            } else {
                defaults.set(false, forKey: "flood_active_notified")
            }
        } else {
            if lastFloodLevel == "I lartë" {
                defaults.set(currentFlood, forKey: "last_flood_level")
            }
            defaults.set(false, forKey: "flood_active_notified")
        }

        // 2. Fire threat level and active checks
        if currentFire == "I lartë" || currentFire == "Ekstrem" {
            if lastFireLevel != currentFire {
                let title = currentFire == "Ekstrem" ? "🚨 Rrezik Zjarri Ekstrem" : "⚠️ Rrezik Zjarri i Lartë"
                let body = currentFire == "Ekstrem"
                    ? "Kushte jashtëzakonisht të rrezikshme për zjarr pranë Çajupit. Shmangni çdo flakë."
                    : "Kushte të thata, nxehtësi dhe erë e fortë pranë Çajupit. Rrezik i lartë për zjarr."
                triggerNotification(title: title, body: body)
                defaults.set(currentFire, forKey: "last_fire_level")
            }
            
            // Extreme threat or active fire conditions count as fire actually happening
            if currentFire == "Ekstrem" || data.current.temperature >= 40.0 {
                if !fireActiveNotified {
                    triggerNotification(
                        title: "🚨 RREZIK EKSTREM ZJARRI",
                        body: "Kushte zjarri po ndodhin! Temperatura është \(String(format: "%.1f", data.current.temperature))°C me lagështi \(data.current.humidity)%."
                    )
                    defaults.set(true, forKey: "fire_active_notified")
                }
            } else {
                defaults.set(false, forKey: "fire_active_notified")
            }
        } else {
            if lastFireLevel == "I lartë" || lastFireLevel == "Ekstrem" {
                defaults.set(currentFire, forKey: "last_fire_level")
            }
            defaults.set(false, forKey: "fire_active_notified")
        }

        // 3. Earthquake check
        for eq in data.earthquakes {
            let timeDiffMs = Date().timeIntervalSince1970 * 1000 - Double(eq.time)
            let oneHourInMs: Double = 60 * 60 * 1000
            guard timeDiffMs < oneHourInMs else { continue }
            
            if eq.magnitude >= 4.0 && eq.isDeep {
                let lastNotifiedId = defaults.string(forKey: "last_notified_earthquake_id") ?? ""
                if lastNotifiedId != eq.id {
                    triggerNotification(
                        title: "🚨 ALERT: TËRMET I NDIJSHËM",
                        body: "Një tërmet prej mag. \(String(format: "%.1f", eq.magnitude)) goditi pranë \(eq.place) (\(Int(eq.distance.rounded())) km larg). Shkundje e fortë pritet në zonë!"
                    )
                    defaults.set(eq.id, forKey: "last_notified_earthquake_id")
                    break // Notify only for the newest qualifying earthquake
                }
            }
        }
    }

    static func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: refreshTaskId)
        // Earliest begin date: 20 minutes from now
        request.earliestBeginDate = Date(timeIntervalSinceNow: 20 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
            print("Background refresh scheduled successfully.")
        } catch {
            print("Could not schedule app refresh task: \(error)")
        }
    }
}
