//
//  NexusWatchApp.swift
//  NexusWatch Watch App
//
//  Created by Nathik Azad on 1/20/26.
//

import SwiftUI

@main
struct NexusWatch_Watch_AppApp: App {
    // Initialize connectivity manager early
    @StateObject private var connectivityManager = WatchConnectivityManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
