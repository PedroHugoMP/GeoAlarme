import Foundation
import UserNotifications

final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    private let center = UNUserNotificationCenter.current()

    override init() {
        super.init()
        center.delegate = self
    }

    func requestAuthorization() async throws {
        let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        guard granted else {
            throw NotificationError.permissionDenied
        }
    }

    func sendRegionEntryNotification(for destination: AlarmDestination) async throws {
        let content = UNMutableNotificationContent()
        content.title = "Você está chegando!"
        content.body = "Você entrou no raio de alerta de \(destination.name)."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "GeoAlarme.regionEntry",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        try await center.add(request)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list])
    }
}

private enum NotificationError: LocalizedError {
    case permissionDenied

    var errorDescription: String? {
        "Permita notificações do GeoAlarme em Ajustes para receber o alerta."
    }
}
