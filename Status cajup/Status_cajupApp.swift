//
//  Status_cajupApp.swift
//  Status cajup
//
//  Created by Martin Hafizi on 8.6.26.
//

import SwiftUI
import BackgroundTasks

@main
struct Status_cajupApp: App {
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    // Request notification permissions when app launches
                    NotificationManager.requestPermission()
                }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .background {
                // Schedule next background refresh when app enters background
                NotificationManager.scheduleAppRefresh()
            }
        }
        .backgroundTask(.appRefresh(NotificationManager.refreshTaskId)) {
            // Re-schedule refresh task
            NotificationManager.scheduleAppRefresh()
            
            // Perform background refresh
            do {
                let data = try await APIService.fetchStats()
                NotificationManager.checkAndTriggerNotifications(data: data)
            } catch {
                print("Background refresh failed to fetch: \(error)")
            }
        }
    }
}
