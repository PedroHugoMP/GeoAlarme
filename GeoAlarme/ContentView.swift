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

    var body: some View {
        ZStack {
            Color(red: 0.035, green: 0.055, blue: 0.09).ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    searchField
                    destinationMap
                        .frame(height: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .overlay(alignment: .bottomLeading) {
                            Text("Toque no mapa para marcar um destino")
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(.black.opacity(0.72), in: Capsule())
                                .padding(12)
                        }

                    destinationCard
                    radiusControl
                    statusCard
                    actionButtons
                    if let message = alarmManager.errorMessage ?? locationManager.errorMessage ?? searchError {
                        Label(message, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
                    }
                    Text("O monitoramento depende das permissões e das condições do iOS. O GeoAlarme não garante um alerta ininterrupto.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.55))
                        .padding(.bottom, 20)
                }
                .padding(20)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
        }
        .task {
            if let destination = selectedDestination {
                moveMap(to: destination.coordinate)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("GeoAlarme")
                .font(.largeTitle.bold())
                .foregroundStyle(.white)
            Text("Descanse. Nós avisamos quando estiver chegando.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.65))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(.white.opacity(0.6))
            TextField("Buscar estação, endereço ou local", text: $searchText)
                .submitLabel(.search)
                .onSubmit { searchDestination() }
                .disabled(alarmManager.isLocked)
            if isSearching {
                ProgressView().tint(.white)
            } else {
                Button(action: searchDestination) {
                    Text("Buscar").fontWeight(.semibold)
                }
                .disabled(searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || alarmManager.isLocked)
            }
        }
        .padding(15)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
        .foregroundStyle(.white)
    }

    private var destinationMap: some View {
        MapReader { proxy in
            Map(position: $cameraPosition) {
                if let destination = selectedDestination {
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
                    }
            )
        }
    }

    private var destinationCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("SEU DESTINO")
                .font(.caption2.bold())
                .tracking(1.2)
                .foregroundStyle(.white.opacity(0.55))
            Text(selectedDestination?.name ?? "Pesquise ou marque no mapa")
                .font(.headline)
                .foregroundStyle(.white)
                .lineLimit(2)
            if let destination = selectedDestination {
                Text(String(format: "%.5f, %.5f", destination.latitude, destination.longitude))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 18))
    }

    private var radiusControl: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Raio de alerta").font(.headline)
                Spacer()
                Text("\(Int(alarmManager.radiusMeters)) m")
                    .font(.title3.bold().monospacedDigit())
                    .foregroundStyle(.orange)
            }
            Slider(value: $alarmManager.radiusMeters, in: 100...5_000, step: 100)
                .tint(.orange)
                .disabled(alarmManager.isLocked)
            HStack {
                Text("100 m")
                Spacer()
                Text("5.000 m")
            }
            .font(.caption2)
            .foregroundStyle(.white.opacity(0.5))
        }
        .foregroundStyle(.white)
        .padding(16)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 18))
    }

    private var statusCard: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(statusColor)
                .frame(width: 11, height: 11)
                .shadow(color: statusColor.opacity(0.7), radius: 7)
            VStack(alignment: .leading, spacing: 3) {
                Text(alarmManager.state.title).font(.headline)
                if alarmManager.state == .active, let configuration = alarmManager.configuration {
                    Text("Aviso a \(Int(configuration.radiusMeters)) m de \(configuration.destination.name)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(2)
                } else if alarmManager.state == .triggered {
                    Text("O som pode ser desligado abaixo.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            Spacer()
        }
        .foregroundStyle(.white)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 18))
    }

    private var actionButtons: some View {
        VStack(spacing: 10) {
            if alarmManager.state == .triggered {
                Button {
                    alarmManager.stopAlarm()
                } label: {
                    Label("Desligar alarme", systemImage: "stop.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(PrimaryButtonStyle(color: .orange))
            } else if alarmManager.state == .active {
                Button {
                    alarmManager.stopAlarm()
                } label: {
                    Label("Cancelar monitoramento", systemImage: "xmark")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(PrimaryButtonStyle(color: Color(red: 0.55, green: 0.25, blue: 0.3)))
            } else {
                Button {
                    Task { await alarmManager.startAlarm() }
                } label: {
                    Label("Ativar GeoAlarme", systemImage: "location.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(PrimaryButtonStyle(color: .orange))
                .disabled(selectedDestination == nil)
                .opacity(selectedDestination == nil ? 0.5 : 1)
            }
        }
        .font(.headline)
    }

    private var statusColor: Color {
        switch alarmManager.state {
        case .active: return .green
        case .triggered: return .orange
        case .cancelled: return .red
        case .ready: return .white.opacity(0.35)
        }
    }

    private func searchDestination() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty, !alarmManager.isLocked else { return }

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
            .foregroundStyle(.white)
            .background(color.opacity(configuration.isPressed ? 0.75 : 1), in: RoundedRectangle(cornerRadius: 16))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}
