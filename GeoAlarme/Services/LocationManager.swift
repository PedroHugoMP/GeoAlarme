import CoreLocation
import Combine
import Foundation

final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    @Published private(set) var servicesEnabled: Bool
    @Published var errorMessage: String?

    private let manager = CLLocationManager()
    private let regionIdentifier = "GeoAlarme.destination"
    private var pendingConfiguration: AlarmConfiguration?
    private var authorizationStep: AuthorizationStep = .none

    var onRegionEntered: (() -> Void)?
    var onMonitoringError: ((String) -> Void)?

    private enum AuthorizationStep {
        case none
        case waitingForWhenInUse
        case waitingForAlways
    }

    override init() {
        authorizationStatus = manager.authorizationStatus
        servicesEnabled = CLLocationManager.locationServicesEnabled()
        super.init()
        manager.delegate = self
    }

    func requestMonitoring(for configuration: AlarmConfiguration) {
        errorMessage = nil
        servicesEnabled = CLLocationManager.locationServicesEnabled()

        guard servicesEnabled else {
            reportMonitoringError("Ative os Serviços de Localização em Ajustes para usar o GeoAlarme.")
            return
        }
        guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else {
            reportMonitoringError("Este aparelho não oferece monitoramento de regiões geográficas.")
            return
        }

        pendingConfiguration = configuration
        switch manager.authorizationStatus {
        case .notDetermined:
            authorizationStep = .waitingForWhenInUse
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse:
            authorizationStep = .waitingForAlways
            manager.requestAlwaysAuthorization()
        case .authorizedAlways:
            beginMonitoring(configuration)
        case .denied, .restricted:
            reportMonitoringError("A localização precisa estar autorizada como “Sempre”. Altere a permissão em Ajustes > GeoAlarme > Localização.")
        @unknown default:
            reportMonitoringError("Não foi possível determinar a autorização de localização.")
        }
    }

    func restoreMonitoring(for configuration: AlarmConfiguration) {
        servicesEnabled = CLLocationManager.locationServicesEnabled()
        guard servicesEnabled else {
            reportMonitoringError("Os Serviços de Localização estão desativados. Ative-os em Ajustes.")
            return
        }
        guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else {
            reportMonitoringError("Este aparelho não oferece monitoramento de regiões geográficas.")
            return
        }
        guard manager.authorizationStatus == .authorizedAlways else {
            reportMonitoringError("O monitoramento salvo não pode ser retomado sem a permissão de localização “Sempre”.")
            return
        }
        beginMonitoring(configuration)
    }

    func stopMonitoring() {
        pendingConfiguration = nil
        authorizationStep = .none
        for region in manager.monitoredRegions where region.identifier == regionIdentifier {
            manager.stopMonitoring(for: region)
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        guard let configuration = pendingConfiguration else { return }

        switch (authorizationStep, manager.authorizationStatus) {
        case (.waitingForWhenInUse, .authorizedWhenInUse):
            authorizationStep = .waitingForAlways
            manager.requestAlwaysAuthorization()
        case (_, .authorizedAlways):
            authorizationStep = .none
            beginMonitoring(configuration)
        case (.waitingForAlways, .authorizedWhenInUse):
            reportMonitoringError("Para monitorar a região em segundo plano, permita a localização “Sempre” nos Ajustes.")
        case (_, .denied), (_, .restricted):
            reportMonitoringError("Permissão de localização negada. Ative a localização “Sempre” em Ajustes.")
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard region.identifier == regionIdentifier else { return }
        onRegionEntered?()
    }

    func locationManager(_ manager: CLLocationManager, didStartMonitoringFor region: CLRegion) {
        guard region.identifier == regionIdentifier else { return }
        manager.requestState(for: region)
    }

    func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        guard region.identifier == regionIdentifier, state == .inside else { return }
        onRegionEntered?()
    }

    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        let detail = region == nil ? error.localizedDescription : "Falha no monitoramento da região: \(error.localizedDescription)"
        reportMonitoringError(detail)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        errorMessage = "Erro dos Serviços de Localização: \(error.localizedDescription)"
    }

    private func beginMonitoring(_ configuration: AlarmConfiguration) {
        pendingConfiguration = nil
        authorizationStep = .none

        let destination = configuration.destination
        guard CLLocationCoordinate2DIsValid(destination.coordinate) else {
            reportMonitoringError("As coordenadas do destino são inválidas.")
            return
        }

        let maximumRadius = manager.maximumRegionMonitoringDistance
        guard maximumRadius > 0, configuration.radiusMeters <= maximumRadius else {
            reportMonitoringError("O raio escolhido excede o limite de \(Int(maximumRadius)) m permitido por este aparelho.")
            return
        }

        let existingRegion = manager.monitoredRegions.first { $0.identifier == regionIdentifier }
        if existingRegion == nil, manager.monitoredRegions.count >= 20 {
            reportMonitoringError("O iOS permite monitorar no máximo 20 regiões por aplicativo. Remova outra região antes de continuar.")
            return
        }
        if let existingRegion {
            manager.stopMonitoring(for: existingRegion)
        }

        let region = CLCircularRegion(
            center: destination.coordinate,
            radius: configuration.radiusMeters,
            identifier: regionIdentifier
        )
        region.notifyOnEntry = true
        region.notifyOnExit = false
        manager.startMonitoring(for: region)
        errorMessage = nil
    }

    private func reportMonitoringError(_ message: String) {
        pendingConfiguration = nil
        authorizationStep = .none
        errorMessage = message
        onMonitoringError?(message)
    }
}
