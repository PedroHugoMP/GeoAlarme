import AVFoundation
import Combine
import Foundation

final class AlarmManager: ObservableObject {
    @Published private(set) var configuration: AlarmConfiguration?
    @Published private(set) var state: AlarmState = .ready
    @Published var draftDestination: AlarmDestination?
    @Published var radiusMeters: Double = 2_000
    @Published var errorMessage: String?

    let locationManager: LocationManager

    private let notificationManager: NotificationManager
    private let defaults = UserDefaults.standard
    private let persistenceKey = "GeoAlarme.persistedAlarm.v1"
    private var audioPlayer: AVAudioPlayer?

    var isLocked: Bool {
        state == .active || state == .triggered
    }

    init() {
        let locationManager = LocationManager()
        self.locationManager = locationManager
        notificationManager = NotificationManager()

        locationManager.onRegionEntered = { [weak self] in
            self?.handleRegionEntry()
        }
        locationManager.onMonitoringError = { [weak self] message in
            guard let self else { return }
            self.locationManager.stopMonitoring()
            self.errorMessage = message
            self.state = .cancelled
            self.stopAlarmSound()
            self.persist()
        }

        restorePersistedAlarm()
    }

    func selectDestination(_ destination: AlarmDestination) {
        guard !isLocked else { return }
        draftDestination = destination
        errorMessage = nil
    }

    func startAlarm() async {
        guard let draftDestination else {
            errorMessage = "Pesquise um local ou toque no mapa para escolher o destino."
            return
        }

        do {
            try await notificationManager.requestAuthorization()
        } catch {
            errorMessage = error.localizedDescription
            return
        }

        let newConfiguration = AlarmConfiguration(
            destination: draftDestination,
            radiusMeters: radiusMeters
        )
        configuration = newConfiguration
        state = .active
        errorMessage = nil
        persist()
        locationManager.requestMonitoring(for: newConfiguration)
    }

    func stopAlarm() {
        locationManager.stopMonitoring()
        stopAlarmSound()
        state = .cancelled
        errorMessage = nil
        persist()
    }

    #if DEBUG
    func simulateRegionEntryForTesting() {
        handleRegionEntry()
    }
    #endif

    private func handleRegionEntry() {
        guard state == .active, let configuration else { return }

        state = .triggered
        locationManager.stopMonitoring()
        persist()

        do {
            try playAlarmSound()
        } catch {
            errorMessage = "O alarme foi disparado, mas o som não pôde ser reproduzido: \(error.localizedDescription)"
        }

        Task {
            do {
                try await notificationManager.sendRegionEntryNotification(for: configuration.destination)
            } catch {
                await MainActor.run {
                    self.errorMessage = "O alarme foi disparado, mas a notificação falhou: \(error.localizedDescription)"
                }
            }
        }
    }

    private func playAlarmSound() throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playback, mode: .default)
        try audioSession.setActive(true)

        let player = try AVAudioPlayer(data: Self.makeAlarmSoundData())
        player.numberOfLoops = -1
        player.prepareToPlay()
        guard player.play() else {
            throw AlarmAudioError.playbackFailed
        }
        audioPlayer = player
    }

    private static func makeAlarmSoundData() -> Data {
        let sampleRate: UInt32 = 22_050
        let sampleCount = Int(sampleRate) * 2
        var data = Data()
        data.append(contentsOf: "RIFF".utf8)
        appendLittleEndian(UInt32(36 + sampleCount * 2), to: &data)
        data.append(contentsOf: "WAVEfmt ".utf8)
        appendLittleEndian(UInt32(16), to: &data)
        appendLittleEndian(UInt16(1), to: &data)
        appendLittleEndian(UInt16(1), to: &data)
        appendLittleEndian(sampleRate, to: &data)
        appendLittleEndian(sampleRate * 2, to: &data)
        appendLittleEndian(UInt16(2), to: &data)
        appendLittleEndian(UInt16(16), to: &data)
        data.append(contentsOf: "data".utf8)
        appendLittleEndian(UInt32(sampleCount * 2), to: &data)

        for index in 0..<sampleCount {
            let time = Double(index) / Double(sampleRate)
            let tonePosition = time.truncatingRemainder(dividingBy: 0.75)
            let toneDuration = 0.42
            let edge = min(tonePosition, toneDuration - tonePosition)
            let envelope = tonePosition < toneDuration ? min(1, max(0, edge / 0.015)) : 0
            let frequency = Int(time / 0.75).isMultiple(of: 2) ? 880.0 : 660.0
            let value = sin(2 * Double.pi * frequency * time) * envelope * 0.22
            let sample = Int16(value * Double(Int16.max))
            appendLittleEndian(UInt16(bitPattern: sample), to: &data)
        }
        return data
    }

    private static func appendLittleEndian<T: FixedWidthInteger>(_ value: T, to data: inout Data) {
        var littleEndian = value.littleEndian
        withUnsafeBytes(of: &littleEndian) { data.append(contentsOf: $0) }
    }

    private func stopAlarmSound() {
        audioPlayer?.stop()
        audioPlayer = nil
    }

    private func restorePersistedAlarm() {
        guard let data = defaults.data(forKey: persistenceKey) else { return }
        do {
            let saved = try JSONDecoder().decode(PersistedAlarm.self, from: data)
            configuration = saved.configuration
            state = saved.state
            draftDestination = saved.configuration?.destination
            radiusMeters = saved.configuration?.radiusMeters ?? 2_000

            if saved.state == .active, let configuration = saved.configuration {
                locationManager.restoreMonitoring(for: configuration)
            }
        } catch {
            errorMessage = "Não foi possível recuperar o alarme salvo: \(error.localizedDescription)"
        }
    }

    private func persist() {
        let saved = PersistedAlarm(configuration: configuration, state: state)
        do {
            defaults.set(try JSONEncoder().encode(saved), forKey: persistenceKey)
        } catch {
            errorMessage = "Não foi possível salvar o alarme: \(error.localizedDescription)"
        }
    }
}

private enum AlarmAudioError: LocalizedError {
    case playbackFailed

    var errorDescription: String? {
        "O sistema não iniciou a reprodução do alarme."
    }
}
