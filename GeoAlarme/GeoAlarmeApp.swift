import SwiftUI

@main
struct GeoAlarmeApp: App {
    @StateObject private var alarmManager = AlarmManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(alarmManager)
                .environmentObject(alarmManager.locationManager)
                .preferredColorScheme(.dark)
        }
    }
}
