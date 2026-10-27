import MapKit
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var alarmManager: AlarmManager
    @EnvironmentObject private var locationManager: LocationManager

    @State private var searchText = ""
    @State private var searchError: String?
    @State private var isSearching = false
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: -23.5505, longitude: -46.6333),
            span: MKCoordinateSpan(latitudeDelta: 0.12, longitudeDelta: 0.12)
        )
    )

    private var selectedDestination: AlarmDestination? {
        if alarmManager.isLocked {
            return alarmManager.configuration?.destination
        }
        return alarmManager.draftDestination ?? alarmManager.configuration?.destination
    }

    private var displayedError: String? {
        alarmManager.errorMessage ?? locationManager.errorMessage ?? searchError
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.035, green: 0.055, blue: 0.09),
                    Color(red: 0.055, green: 0.085, blue: 0.13),
                    Color(red: 0.025, green: 0.04, blue: 0.07)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    searchField
                    destinationMap
                    destinationCard
                    radiusControl
                    statusCard

                    if let displayedError {
                        errorBanner(displayedError)
                    }

                    actionButtons
                    footer
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 28)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
        }
        .preferredColorScheme(.dark)
        .task {
            if let destination = selectedDestination {
                moveMap(to: destination.coordinate)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.orange.opacity(0.16))
                        .frame(width: 52, height: 52)
                    Image(systemName: "location.north.circle.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.orange)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text("GEOALARME")
                        .font(.caption.weight(.bold))
                        .tracking(2.2)
                        .foregroundStyle(.orange)
                    Text("Chegue tranquilo.")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                }
                .padding(.top, 2)

                Spacer(minLength: 4)

                stateBadge
            }

            Text("Escolha um destino e receba um aviso ao se aproximar.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.65))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var stateBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 7, height: 7)
            Text(stateBadgeTitle)
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
        }
        .foregroundStyle(.white.opacity(0.9))
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.white.opacity(0.08), in: Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Estado do alarme: \(stateBadgeTitle)")
    }

    private var searchField: some View {
        HStack(spacing: 11) {
            Image(systemName: "magnifyingglass")
                .font(.body.weight(.semibold))
                .foregroundStyle(.orange)
                .accessibilityHidden(true)

            TextField("Buscar endereço ou local", text: $searchText)
                .font(.subheadline)
                .submitLabel(.search)
                .onSubmit(searchDestination)
                .disabled(alarmManager.isLocked)
                .accessibilityLabel("Buscar estação, endereço ou local")

            if isSearching {
                ProgressView()
                    .tint(.orange)
                    .accessibilityLabel("Pesquisando")
            } else {
                Button(action: searchDestination) {
                    Text("Buscar")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.orange)
                }
                .disabled(searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || alarmManager.isLocked)
                .accessibilityHint("Pesquisa o local informado")
            }
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 56)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        }
    }

    private var destinationMap: some View {
        MapReader { proxy in
            Map(position: $cameraPosition) {
                if let destination = selectedDestination {
                    MapCircle(
                        center: destination.coordinate,
                        radius: alarmManager.isLocked
                            ? (alarmManager.configuration?.radiusMeters ?? alarmManager.radiusMeters)
                            : alarmManager.radiusMeters
                    )
                    .foregroundStyle(.orange.opacity(0.14))
                    .stroke(.orange.opacity(0.8), lineWidth: 2)

                    Marker(destination.name, coordinate: destination.coordinate)
                        .tint(.orange)
                }
            }
            .mapStyle(.standard(elevation: .flat, pointsOfInterest: .all))
            .simultaneousGesture(
                SpatialTapGesture()
                    .onEnded { event in
                        guard !alarmManager.isLocked,
                              let coordinate = proxy.convert(event.location, from: .local),
                              CLLocationCoordinate2DIsValid(coordinate) else { return }
                        let destination = AlarmDestination(
                            name: String(format: "Destino (%.4f, %.4f)", coordinate.latitude, coordinate.longitude),
                            coordinate: coordinate
                        )
                        alarmManager.selectDestination(destination)
                        searchError = nil
                    }
            )
            .overlay(alignment: .topLeading) {
                Label(selectedDestination == nil ? "ESCOLHA NO MAPA" : "ÁREA DE ALERTA", systemImage: "scope")
                    .font(.caption2.weight(.bold))
                    .tracking(0.7)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 9)
                    .background(.black.opacity(0.68), in: Capsule())
                    .padding(12)
            }
            .overlay(alignment: .bottomLeading) {
                Label("Toque para marcar o destino", systemImage: "hand.tap")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.92))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(.black.opacity(0.72), in: Capsule())
                    .padding(12)
            }
            .frame(height: 285)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay {
                RoundedRectangle(cornerRadius: 24)
                    .stroke(.white.opacity(0.1), lineWidth: 1)
            }
            .accessibilityLabel("Mapa para selecionar o destino")
        }
    }

    private var destinationCard: some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: "mappin.and.ellipse")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.orange)
                .frame(width: 42, height: 42)
                .background(.orange.opacity(0.13), in: RoundedRectangle(cornerRadius: 13))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                Text("SEU DESTINO")
                    .font(.caption2.weight(.bold))
                    .tracking(1.3)
                    .foregroundStyle(.white.opacity(0.5))
                Text(selectedDestination?.name ?? "Pesquise ou marque no mapa")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .accessibilityIdentifier("selectedDestinationName")
                if let destination = selectedDestination {
                    Text(String(format: "%.5f, %.5f", destination.latitude, destination.longitude))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.52))
                } else {
                    Text("O alarme será configurado para este ponto")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.52))
                }
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.065), in: RoundedRectangle(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(.white.opacity(0.07), lineWidth: 1)
        }
    }

    private var radiusControl: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Distância do aviso")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("Você será avisado ao entrar nesta área")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.55))
                }
                Spacer()
                Text(radiusDescription)
                    .font(.title3.bold().monospacedDigit())
                    .foregroundStyle(.orange)
                    .contentTransition(.numericText())
                    .accessibilityLabel("Raio: \(Int(alarmManager.radiusMeters)) metros")
            }

            Slider(value: $alarmManager.radiusMeters, in: 100...5_000, step: 100)
                .tint(.orange)
                .disabled(alarmManager.isLocked)
                .accessibilityLabel("Raio de alerta")
                .accessibilityValue("\(Int(alarmManager.radiusMeters)) metros")

            HStack {
                Label("100 m", systemImage: "smallcircle.filled.circle")
                Spacer()
                Label("5 km", systemImage: "circle.dashed")
            }
            .font(.caption2.weight(.medium))
            .foregroundStyle(.white.opacity(0.45))
        }
        .padding(17)
        .background(.white.opacity(0.065), in: RoundedRectangle(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(.white.opacity(0.07), lineWidth: 1)
        }
    }

    private var statusCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: statusIcon)
                .font(.title3.weight(.semibold))
                .foregroundStyle(statusColor)
                .frame(width: 42, height: 42)
                .background(statusColor.opacity(0.13), in: RoundedRectangle(cornerRadius: 13))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                Text(alarmManager.state.title)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(statusDescription)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.58))
                    .fixedSize(horizontal: false, vertical: true)
                Text(locationPermissionDescription)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.43))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.065), in: RoundedRectangle(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(statusColor.opacity(0.18), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private var actionButtons: some View {
        VStack(spacing: 11) {
            if alarmManager.state == .triggered {
                Button(action: alarmManager.stopAlarm) {
                    Label("Desligar alarme", systemImage: "stop.fill")
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 54)
                }
                .buttonStyle(PrimaryButtonStyle(color: .orange))
            } else if alarmManager.state == .active {
                Button(action: alarmManager.stopAlarm) {
                    Label("Cancelar monitoramento", systemImage: "xmark")
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 54)
                }
                .buttonStyle(PrimaryButtonStyle(color: Color(red: 0.55, green: 0.25, blue: 0.3)))

                #if DEBUG
                Button(action: alarmManager.simulateRegionEntryForTesting) {
                    Label("Simular chegada", systemImage: "location.circle")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.orange)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 46)
                        .background(.orange.opacity(0.09), in: RoundedRectangle(cornerRadius: 16))
                }
                .accessibilityHint("Dispara o mesmo fluxo de chegada usado pelo monitoramento, apenas para testes")
                #endif
            } else {
                Button {
                    Task { await alarmManager.startAlarm() }
                } label: {
                    Label("Ativar GeoAlarme", systemImage: "location.fill")
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 54)
                }
                .buttonStyle(PrimaryButtonStyle(color: .orange))
                .disabled(selectedDestination == nil)
                .opacity(selectedDestination == nil ? 0.5 : 1)
                .accessibilityHint(selectedDestination == nil ? "Escolha um destino antes de ativar" : "Solicita as permissões e inicia o monitoramento")
            }
        }
        .font(.headline)
    }

    private var footer: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle")
                .accessibilityHidden(true)
            Text("O aviso depende das permissões, do sinal e das condições do iOS. Não há garantia de alerta ininterrupto.")
        }
        .font(.caption2)
        .foregroundStyle(.white.opacity(0.42))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 2)
    }

    private func errorBanner(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.footnote.weight(.medium))
            .foregroundStyle(.orange)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.orange.opacity(0.11), in: RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(.orange.opacity(0.2), lineWidth: 1)
            }
            .accessibilityAddTraits(.updatesFrequently)
    }

    private var stateBadgeTitle: String {
        switch alarmManager.state {
        case .ready: return "PRONTO"
        case .active: return "ATIVO"
        case .triggered: return "ALERTA"
        case .cancelled: return "PAUSADO"
        }
    }

    private var statusColor: Color {
        switch alarmManager.state {
        case .active: return .green
        case .triggered: return .orange
        case .cancelled: return .white.opacity(0.48)
        case .ready: return .cyan.opacity(0.8)
        }
    }

    private var statusIcon: String {
        switch alarmManager.state {
        case .active: return "location.circle.fill"
        case .triggered: return "bell.badge.fill"
        case .cancelled: return "pause.circle.fill"
        case .ready: return "checkmark.circle.fill"
        }
    }

    private var statusDescription: String {
        switch alarmManager.state {
        case .active:
            guard let configuration = alarmManager.configuration else {
                return "Aguardando entrada na região selecionada."
            }
            return "Aviso a \(Int(configuration.radiusMeters)) m de \(configuration.destination.name)."
        case .triggered:
            return "Você entrou na região. Desligue o alarme quando quiser."
        case .cancelled:
            return "O monitoramento está pausado. Você pode configurar outro destino."
        case .ready:
            return "Escolha um destino e ative o monitoramento."
        }
    }

    private var locationPermissionDescription: String {
        guard locationManager.servicesEnabled else {
            return "Serviços de Localização desativados no aparelho."
        }
        switch locationManager.authorizationStatus {
        case .authorizedAlways:
            return "Localização permitida sempre."
        case .authorizedWhenInUse:
            return "Localização permitida durante o uso; o iOS pode pedir acesso Sempre."
        case .denied:
            return "Localização negada. Altere a permissão nos Ajustes."
        case .restricted:
            return "A localização está restrita neste aparelho."
        case .notDetermined:
            return "A permissão de localização será solicitada ao ativar."
        @unknown default:
            return "Estado da permissão de localização desconhecido."
        }
    }

    private var radiusDescription: String {
        if alarmManager.radiusMeters >= 1_000 {
            return String(format: "%.1f km", alarmManager.radiusMeters / 1_000)
        }
        return "\(Int(alarmManager.radiusMeters)) m"
    }

    private func searchDestination() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty, !alarmManager.isLocked, !isSearching else { return }

        isSearching = true
        searchError = nil
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = cameraPosition.region ?? MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: -23.5505, longitude: -46.6333),
            span: MKCoordinateSpan(latitudeDelta: 1, longitudeDelta: 1)
        )

        Task {
            defer { isSearching = false }
            do {
                let response = try await MKLocalSearch(request: request).start()
                guard let item = response.mapItems.first else {
                    searchError = "Nenhum resultado encontrado. Tente outro endereço ou marque no mapa."
                    return
                }
                let name = item.name ?? query
                alarmManager.selectDestination(AlarmDestination(name: name, coordinate: item.placemark.coordinate))
                moveMap(to: item.placemark.coordinate)
            } catch {
                searchError = "Não foi possível pesquisar este local: \(error.localizedDescription)"
            }
        }
    }

    private func moveMap(to coordinate: CLLocationCoordinate2D) {
        cameraPosition = .region(
            MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
            )
        )
    }
}

private struct PrimaryButtonStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .background(
                color.opacity(configuration.isPressed ? 0.78 : 1),
                in: RoundedRectangle(cornerRadius: 17)
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}
