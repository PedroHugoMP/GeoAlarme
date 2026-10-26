import CoreLocation
import Foundation

struct AlarmDestination: Codable, Equatable, Identifiable {
    var id: String { "\(latitude),\(longitude)" }
    let name: String
    let latitude: Double
    let longitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    init(name: String, coordinate: CLLocationCoordinate2D) {
        self.name = name
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
    }
}

struct AlarmConfiguration: Codable, Equatable {
    let destination: AlarmDestination
    let radiusMeters: Double
}

enum AlarmState: String, Codable {
    case ready
    case active
    case triggered
    case cancelled

    var title: String {
        switch self {
        case .ready: return "Pronto para configurar"
        case .active: return "Monitoramento ativo"
        case .triggered: return "Alarme disparado"
        case .cancelled: return "Cancelado"
        }
    }
}

struct PersistedAlarm: Codable {
    let configuration: AlarmConfiguration?
    let state: AlarmState
}
