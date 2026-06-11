//
//  ContentView.swift
//  Status cajup
//

import SwiftUI

// MARK: - Detail Card Enum (here so both files can see it)

enum DetailCard: String, Identifiable {
    case current, humidity, wind, rain, airQuality, hazards, forecast
    var id: String { rawValue }

    var title: String {
        switch self {
        case .current:    return "Kushtet Aktuale"
        case .humidity:   return "Lagështia"
        case .wind:       return "Era"
        case .rain:       return "Reshjet e Shiut"
        case .airQuality: return "Cilësia e Ajrit"
        case .hazards:    return "Rreziqet Natyrore"
        case .forecast:   return "Parashikimi 3-Ditor"
        }
    }

    var icon: String {
        switch self {
        case .current:    return "thermometer.medium"
        case .humidity:   return "humidity"
        case .wind:       return "wind"
        case .rain:       return "cloud.rain.fill"
        case .airQuality: return "aqi.medium"
        case .hazards:    return "shield.lefthalf.filled"
        case .forecast:   return "calendar"
        }
    }
}

// MARK: - ViewModel

@Observable
final class EnvViewModel {
    var data: EnvironmentData?
    var isLoading = false
    var error: String?

    func load() async {
        isLoading = true
        error = nil
        do {
            data = try await APIService.fetchStats()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Shared gradient

func getAppGradient(isGreen: Bool) -> LinearGradient {
    if isGreen {
        return LinearGradient(
            colors: [
                Color(red: 0.02, green: 0.15, blue: 0.08),
                Color(red: 0.05, green: 0.25, blue: 0.15),
                Color(red: 0.01, green: 0.10, blue: 0.05),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    } else {
        return LinearGradient(
            colors: [
                Color(red: 0.04, green: 0.13, blue: 0.30),
                Color(red: 0.07, green: 0.22, blue: 0.42),
                Color(red: 0.02, green: 0.09, blue: 0.25),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Welcome View
struct WelcomeView: View {
    @Binding var hasSeenWelcome: Bool
    @State private var isTitleVisible = false
    @State private var isButtonVisible = false
    @AppStorage("useGreenGradient") private var useGreenGradient = false

    var body: some View {
        ZStack {
            getAppGradient(isGreen: useGreenGradient).ignoresSafeArea()
            
            VStack {
                Spacer()
                
                VStack(spacing: 32) {
                    Text("Ky është Syri Mbrojtës.")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .opacity(isTitleVisible ? 1.0 : 0.0)
                        .scaleEffect(isTitleVisible ? 1.0 : 0.95)
                    
                    if isButtonVisible {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 1.0)) {
                                hasSeenWelcome = true
                            }
                        }) {
                            Text("Hyni")
                                .font(.headline.bold())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 48)
                                .padding(.vertical, 16)
                                .background(
                                    Capsule()
                                        .fill(.white.opacity(0.12))
                                        .background(
                                            Capsule()
                                                .stroke(.white.opacity(0.2), lineWidth: 1.5)
                                        )
                                )
                        }
                        .buttonStyle(PressableGlassButtonStyle())
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    } else {
                        Spacer().frame(height: 54)
                    }
                }
                
                Spacer()
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.2)) {
                isTitleVisible = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation(.easeOut(duration: 0.8)) {
                    isButtonVisible = true
                }
            }
        }
    }
}

// MARK: - Root

struct ContentView: View {
    @State private var vm = EnvViewModel()
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false
    @AppStorage("useGreenGradient") private var useGreenGradient = false

    var body: some View {
        ZStack {
            getAppGradient(isGreen: useGreenGradient).ignoresSafeArea()
            
            if !hasSeenWelcome {
                WelcomeView(hasSeenWelcome: $hasSeenWelcome)
                    .transition(.opacity)
            } else {
                ZStack {
                    if vm.isLoading && vm.data == nil {
                        LoadingView()
                    } else if let err = vm.error {
                        ErrorView(message: err) { Task { await vm.load() } }
                    } else if let data = vm.data {
                        MainScrollView(data: data, isLoading: vm.isLoading) {
                            Task {
                                await vm.load()
                                if let updatedData = vm.data {
                                    NotificationManager.checkAndTriggerNotifications(data: updatedData)
                                }
                            }
                        }
                    } else {
                        LoadingView()
                    }
                }
                .transition(.opacity)
            }
        }
        .task {
            await vm.load()
        }
        .onAppear {
            useGreenGradient.toggle()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            useGreenGradient.toggle()
        }
    }
}

// MARK: - Loading / Error

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 10) {
            ProgressView().tint(.white).scaleEffect(1.2)
            Text("Duke marrë të dhënat…")
                .foregroundStyle(.white.opacity(0.6)).font(.caption)
        }
    }
}

struct ErrorView: View {
    let message: String
    let retry: () -> Void
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "antenna.radiowaves.left.and.right.slash")
                .font(.system(size: 36)).foregroundStyle(.white.opacity(0.6))
            Text("Dështoi ngarkimi i të dhënave").font(.headline).foregroundStyle(.white)
            Text(message).font(.caption).foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center).padding(.horizontal, 36)
            Button("Provo Përsëri", action: retry).buttonStyle(.glassProminent)
        }
    }
}

// MARK: - Main Scroll

struct MainScrollView: View {
    let data: EnvironmentData
    let isLoading: Bool
    let refresh: () -> Void
    @State private var selectedCard: DetailCard?

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                HeaderView(data: data, isLoading: isLoading, refresh: refresh)

                Button {
                    selectedCard = .current
                } label: {
                    CurrentConditionsCard(cur: data.current)
                }
                .buttonStyle(GlassCardButtonStyle())
                .contentShape(Rectangle())

                HStack(alignment: .top, spacing: 10) {
                    Button {
                        selectedCard = .humidity
                    } label: {
                        HumidityCard(humidity: data.current.humidity)
                    }
                    .buttonStyle(GlassCardButtonStyle())
                    .contentShape(Rectangle())

                    Button {
                        selectedCard = .wind
                    } label: {
                        WindCard(speed: data.current.windSpeed,
                                 gusts: data.current.windGusts,
                                 direction: data.current.windDirection)
                    }
                    .buttonStyle(GlassCardButtonStyle())
                    .contentShape(Rectangle())
                }

                Button {
                    selectedCard = .rain
                } label: {
                    RainCard(rain: data.rain)
                }
                .buttonStyle(GlassCardButtonStyle())
                .contentShape(Rectangle())

                Button {
                    selectedCard = .airQuality
                } label: {
                    AirQualityCard(aq: data.airQuality)
                }
                .buttonStyle(GlassCardButtonStyle())
                .contentShape(Rectangle())

                Button {
                    selectedCard = .hazards
                } label: {
                    DisasterCard(flood: data.disasters.flood, fire: data.disasters.fire, earthquakes: data.earthquakes)
                }
                .buttonStyle(GlassCardButtonStyle())
                .contentShape(Rectangle())

                Button {
                    selectedCard = .forecast
                } label: {
                    ForecastCard(days: data.rain.dailyForecast)
                }
                .buttonStyle(GlassCardButtonStyle())
                .contentShape(Rectangle())

                Link(destination: URL(string: "https://open-meteo.com")!) {
                    Text("Open-Meteo & USGS · Tiranë, Albania")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.25))
                }

                Text("Përditësuar më \(data.updated)")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.22))

                Text("© 2026 Martin Hafizi")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.18))
                    .padding(.bottom, 10)
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)
        }
        .sheet(item: $selectedCard) { card in
            DetailSheetView(card: card, data: data)
        }
    }
}

// MARK: - Header

struct HeaderView: View {
    let data: EnvironmentData
    let isLoading: Bool
    let refresh: () -> Void

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Syri Mbrojtës")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
                Text(data.location)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
            }
            Spacer()
            Button { refresh() } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(
                        Circle()
                            .fill(.white.opacity(0.06))
                            .background(Circle().stroke(.white.opacity(0.12), lineWidth: 1))
                    )
                    .symbolEffect(.rotate, options: .repeating, value: isLoading)
            }
            .disabled(isLoading)
            .buttonStyle(CircularPressableGlassButtonStyle())
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Tap hint (used inside each card)

struct TapChevron: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white.opacity(0.35))
    }
}

// MARK: - Current Conditions Card

struct CurrentConditionsCard: View {
    let cur: CurrentConditions
    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(weatherDescription(cur.weatherCode))
                    .font(.footnote.weight(.medium)).foregroundStyle(.white.opacity(0.75)).lineLimit(1)
                Text("\(Int(cur.temperature.rounded()))°C")
                    .font(.system(size: 40, weight: .light)).foregroundStyle(.white)
                    .lineLimit(1)
                Text("Ndihet si \(Int(cur.feelsLike.rounded()))°C")
                    .font(.footnote).foregroundStyle(.white.opacity(0.55)).lineLimit(1)
            }
            Spacer(minLength: 6)
            VStack(alignment: .trailing, spacing: 0) {
                TapChevron()
                Spacer()
                Image(systemName: weatherIcon(cur.weatherCode))
                    .font(.system(size: 34)).foregroundStyle(.white.opacity(0.85))
                    .symbolEffect(.pulse)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .frame(maxWidth: .infinity, minHeight: 90).glassEffect()
    }
}

// MARK: - Humidity Card

struct HumidityCard: View {
    let humidity: Int
    var color: Color { humidity < 30 ? .yellow : humidity < 60 ? .cyan : .blue }
    var label: String { humidity < 30 ? "E thatë" : humidity < 60 ? "Komode" : "E lagësht" }
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Lagështia", systemImage: "humidity")
                    .font(.footnote.weight(.semibold)).foregroundStyle(.white.opacity(0.6)).lineLimit(1)
                Spacer()
                TapChevron()
            }
            Text("\(humidity)%")
                .font(.system(size: 26, weight: .semibold)).foregroundStyle(.white).lineLimit(1)
            Spacer(minLength: 2)
            GaugeBar(value: Double(humidity) / 100.0, color: color)
            Text(label)
                .font(.footnote).foregroundStyle(.white.opacity(0.55))
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).glassEffect()
    }
}

// MARK: - Wind Card

struct WindCard: View {
    let speed: Double
    let gusts: Double
    let direction: Int
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Era", systemImage: "wind")
                    .font(.footnote.weight(.semibold)).foregroundStyle(.white.opacity(0.6)).lineLimit(1)
                Spacer()
                TapChevron()
            }
            Text("\(Int(speed.rounded())) km/h")
                .font(.system(size: 26, weight: .semibold)).foregroundStyle(.white)
                .lineLimit(1)
            HStack(spacing: 4) {
                Image(systemName: "arrow.up")
                    .rotationEffect(.degrees(Double(direction)))
                    .font(.footnote).foregroundStyle(.white.opacity(0.6))
                Text(cardinalDirection(direction))
                    .font(.footnote).foregroundStyle(.white.opacity(0.6))
            }
            Text("Hove ere \(Int(gusts.rounded())) km/h")
                .font(.footnote).foregroundStyle(.white.opacity(0.45)).lineLimit(1)
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).glassEffect()
    }
    func cardinalDirection(_ deg: Int) -> String {
        ["V","VL","L","JL","J","JV","P","VP"][Int((Double(deg) + 22.5) / 45.0) % 8]
    }
}

// MARK: - Rain Card

struct RainCard: View {
    let rain: RainInfo
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Reshjet", systemImage: "cloud.rain")
                    .font(.footnote.weight(.semibold)).foregroundStyle(.white.opacity(0.6))
                Spacer()
                TapChevron()
            }
            HStack(spacing: 24) {
                MiniStat(value: "\(Int(rain.probabilityNext24h))%", label: "Mundësia 24h")
                MiniStat(value: "\(String(format: "%.1f", rain.totalMmNext24h)) mm", label: "Pritet")
            }
            GaugeBar(value: rain.probabilityNext24h / 100.0, color: .cyan)
            HStack(spacing: 5) {
                if let h = rain.nextRainInHours {
                    Image(systemName: "clock").font(.footnote).foregroundStyle(.cyan.opacity(0.9))
                    Text(h == 0 ? "Duke rënë shi tani" : "Shi pas ~\(h) orësh")
                        .font(.footnote).foregroundStyle(.white.opacity(0.7))
                } else {
                    Image(systemName: "sun.max").font(.footnote).foregroundStyle(.yellow.opacity(0.9))
                    Text("Nuk parashikohet shi për 24h").font(.footnote).foregroundStyle(.white.opacity(0.7))
                }
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).glassEffect()
    }
}

// MARK: - Air Quality Card

struct AirQualityCard: View {
    let aq: AirQuality
    var aqiColor: Color {
        switch aq.europeanAqi {
        case 0...20: return .green; case 21...40: return .yellow
        case 41...60: return .orange; case 61...80: return Color(red:1,green:0.3,blue:0.1)
        default: return .red }
    }
    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                Circle().stroke(.white.opacity(0.13), lineWidth: 4).frame(width: 50, height: 50)
                Circle()
                    .trim(from: 0, to: min(CGFloat(aq.europeanAqi) / 100.0, 1))
                    .stroke(aqiColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 50, height: 50).rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.8), value: aq.europeanAqi)
                Text("\(aq.europeanAqi)").font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 3) {
                Label("Cilësia e Ajrit", systemImage: "aqi.medium")
                    .font(.footnote.weight(.semibold)).foregroundStyle(.white.opacity(0.6))
                Text(aq.label).font(.headline).foregroundStyle(aqiColor)
                Text("PM2.5 · \(String(format: "%.1f", aq.pm2_5)) µg/m³")
                    .font(.footnote).foregroundStyle(.white.opacity(0.55))
            }
            Spacer()
            TapChevron()
        }
        .padding(16).frame(maxWidth: .infinity).glassEffect()
    }
}

// MARK: - Disaster Card

struct DisasterCard: View {
    let flood: DisasterRisk
    let fire: DisasterRisk
    let earthquakes: [EarthquakeEvent]

    var eqRisk: DisasterRisk {
        let recentFelt = earthquakes.first { eq in
            let ageHours = (Date().timeIntervalSince1970 * 1000 - Double(eq.time)) / (1000 * 60 * 60)
            return ageHours < 24 && eq.isFelt
        }
        
        if let eq = recentFelt {
            if eq.isDeep && eq.magnitude >= 4.0 {
                return DisasterRisk(level: "I lartë", description: "Tërmet mag \(String(format: "%.1f", eq.magnitude)) i ndjerë fort.")
            } else {
                return DisasterRisk(level: "Mesatar", description: "Tërmet mag \(String(format: "%.1f", eq.magnitude)) i ndjerë lehtë.")
            }
        } else {
            return DisasterRisk(level: "Minimal", description: "Nuk ka tërmete të ndjeshme së fundmi.")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Rreziqet Natyrore", systemImage: "shield.lefthalf.filled")
                    .font(.footnote.weight(.semibold)).foregroundStyle(.white.opacity(0.6))
                Spacer()
                TapChevron()
            }
            HStack(spacing: 12) {
                CompactHazard(icon: "cloud.heavyrain.fill", title: "Përmbytje", risk: flood)
                Divider().background(.white.opacity(0.15)).frame(height: 30)
                CompactHazard(icon: "flame.fill", title: "Zjarr", risk: fire)
                Divider().background(.white.opacity(0.15)).frame(height: 30)
                CompactHazard(icon: "waveform.path.ecg", title: "Tërmet", risk: eqRisk)
                Spacer()
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).glassEffect()
    }
}

struct CompactHazard: View {
    let icon: String; let title: String; let risk: DisasterRisk
    var color: Color {
        switch risk.level {
        case "Minimal","Low","I ulët": return .green; case "Moderate","Mesatar": return .yellow
        case "High","I lartë": return .orange; default: return .red } // Ekstrem
    }
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 16)).foregroundStyle(color)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.footnote).foregroundStyle(.white.opacity(0.55))
                Text(risk.level).font(.subheadline.bold()).foregroundStyle(color)
            }
        }
    }
}

// MARK: - Forecast Card

struct ForecastCard: View {
    let days: [DayForecast]
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Parashikimi 3-Ditor", systemImage: "calendar")
                    .font(.footnote.weight(.semibold)).foregroundStyle(.white.opacity(0.6))
                Spacer()
                TapChevron()
            }
            ForEach(Array(days.enumerated()), id: \.element.id) { idx, day in
                if idx > 0 { Divider().background(.white.opacity(0.1)) }
                HStack {
                    Text(day.shortDate).font(.subheadline).foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    HStack(spacing: 3) {
                        Image(systemName: "drop.fill").font(.system(size: 10)).foregroundStyle(.cyan.opacity(0.8))
                        Text("\(day.probabilityPct)%").font(.footnote).foregroundStyle(.white.opacity(0.85))
                    }.frame(width: 48)
                    HStack(spacing: 3) {
                        Image(systemName: "cloud.rain").font(.system(size: 10)).foregroundStyle(.blue.opacity(0.7))
                        Text("\(String(format:"%.0f",day.precipitationMm))mm").font(.footnote).foregroundStyle(.white.opacity(0.85))
                    }.frame(width: 52)
                    HStack(spacing: 3) {
                        Image(systemName: "wind").font(.system(size: 10)).foregroundStyle(.white.opacity(0.4))
                        Text("\(Int(day.maxWindKph))km/h").font(.footnote).foregroundStyle(.white.opacity(0.85))
                    }.frame(width: 62)
                }
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).glassEffect()
    }
}

// MARK: - Shared Widgets

struct GaugeBar: View {
    let value: Double; let color: Color
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3).fill(.white.opacity(0.1))
                RoundedRectangle(cornerRadius: 3).fill(color.opacity(0.85))
                    .frame(width: geo.size.width * min(max(value, 0), 1))
                    .animation(.easeOut(duration: 0.6), value: value)
            }
        }
        .frame(height: 4)
    }
}

struct MiniStat: View {
    let value: String; let label: String
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.system(size: 22, weight: .semibold)).foregroundStyle(.white)
                .minimumScaleFactor(0.75).lineLimit(1)
            Text(label).font(.footnote).foregroundStyle(.white.opacity(0.55))
        }
    }
}

// MARK: - Weather Helpers

func weatherIcon(_ code: Int) -> String {
    switch code {
    case 0: return "sun.max.fill"; case 1,2: return "cloud.sun.fill"; case 3: return "cloud.fill"
    case 45,48: return "cloud.fog.fill"; case 51...55: return "cloud.drizzle.fill"
    case 61...65: return "cloud.rain.fill"; case 71...75: return "cloud.snow.fill"
    case 80...82: return "cloud.heavyrain.fill"; case 95: return "cloud.bolt.fill"
    case 96,99: return "cloud.bolt.rain.fill"; default: return "cloud.fill"
    }
}

func weatherDescription(_ code: Int) -> String {
    switch code {
    case 0: return "Qiell i Pastër"
    case 1: return "Kthjellët"
    case 2: return "Vranësira të Lehta"
    case 3: return "Vranët"
    case 45,48: return "Mjegull"
    case 51...55: return "Rigë Shiu"
    case 61...65: return "Shi"
    case 71...75: return "Dëborë"
    case 80...82: return "Rrebesh Shiu"
    case 95: return "Shtrëngatë me Vetëtima"
    case 96,99: return "Shtrëngatë me Breshër"
    default: return "Vranësira"
    }
}

#Preview { ContentView() }

// MARK: - Detail Sheet Root

struct DetailSheetView: View {
    let card: DetailCard
    let data: EnvironmentData
    @Environment(\.dismiss) private var dismiss
    @AppStorage("useGreenGradient") private var useGreenGradient = false

    var body: some View {
        ZStack {
            getAppGradient(isGreen: useGreenGradient).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 14) {
                    Capsule()
                        .fill(.white.opacity(0.25))
                        .frame(width: 36, height: 4)
                        .padding(.top, 10)
                    HStack {
                        Label(card.title, systemImage: card.icon)
                            .font(.title3.bold()).foregroundStyle(.white)
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(10)
                                .background(
                                    Circle()
                                        .fill(.white.opacity(0.06))
                                        .background(Circle().stroke(.white.opacity(0.12), lineWidth: 1))
                                )
                        }
                        .buttonStyle(CircularPressableGlassButtonStyle())
                    }
                    .padding(.horizontal, 18)
                    Group {
                        switch card {
                        case .current:    CurrentDetailView(cur: data.current)
                        case .humidity:   HumidityDetailView(cur: data.current)
                        case .wind:       WindDetailView(cur: data.current)
                        case .rain:       RainDetailView(rain: data.rain)
                        case .airQuality: AirQualityDetailView(aq: data.airQuality)
                        case .hazards:    HazardsDetailView(disasters: data.disasters, cur: data.current, earthquakes: data.earthquakes)
                        case .forecast:   ForecastDetailView(rain: data.rain)
                        }
                    }
                    .padding(.horizontal, 16)
                    Spacer(minLength: 32)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
        .presentationBackground { getAppGradient(isGreen: useGreenGradient) }
    }
}

// MARK: - Shared detail components

struct DetailSection<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.6))
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect()
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    let color: Color
    init(_ label: String, _ value: String, color: Color = .white) {
        self.label = label; self.value = value; self.color = color
    }
    var body: some View {
        HStack {
            Text(label).font(.subheadline).foregroundStyle(.white.opacity(0.6))
            Spacer()
            Text(value).font(.subheadline.weight(.medium)).foregroundStyle(color)
        }
    }
}

// MARK: - Current Detail

struct CurrentDetailView: View {
    let cur: CurrentConditions
    var heatDiff: String {
        let diff = cur.feelsLike - cur.temperature
        if diff > 1  { return "Ndihet \(Int(diff.rounded()))° më nxehtë — lagështi e lartë" }
        if diff < -1 { return "Ndihet \(Int((-diff).rounded()))° më ftohtë — ftohje nga era" }
        return "Ndihet afërsisht njëlloj si temperatura reale"
    }
    var body: some View {
        VStack(spacing: 12) {
            DetailSection(title: "Tani", systemImage: "thermometer.medium") {
                DetailRow("Temperatura", "\(String(format:"%.1f",cur.temperature))°C")
                Divider().background(.white.opacity(0.1))
                DetailRow("Ndihet si", "\(String(format:"%.1f",cur.feelsLike))°C")
                Divider().background(.white.opacity(0.1))
                DetailRow("Kushti", weatherDescription(cur.weatherCode))
                Divider().background(.white.opacity(0.1))
                DetailRow("Reshje Tani", cur.precipitation > 0 ? "\(String(format:"%.1f",cur.precipitation)) mm" : "Asnjë")
            }
            DetailSection(title: "Shpjegimi i Temperaturës së Perceptuar", systemImage: "info.circle") {
                Text(heatDiff).font(.subheadline).foregroundStyle(.white.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
                Divider().background(.white.opacity(0.1)).padding(.vertical, 2)
                Text("Temperatura e perceptuar ('ndihet si') kombinon temperaturën, lagështinë dhe shpejtësinë e erës për të treguar se si trupi ynë e ndjen të nxehtin ose të ftohtin në të vërtetë.")
                    .font(.caption).foregroundStyle(.white.opacity(0.55))
                    .fixedSize(horizontal: false, vertical: true)
            }
            DetailSection(title: "Kodi i Motit WMO", systemImage: "list.number") {
                DetailRow("Kodi", "\(cur.weatherCode)")
                Divider().background(.white.opacity(0.1))
                Text(wmoDescription(cur.weatherCode))
                    .font(.caption).foregroundStyle(.white.opacity(0.55))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
    func wmoDescription(_ code: Int) -> String {
        switch code {
        case 0: return "Qielli është i pastër. Nuk ka vranësira domethënëse."
        case 1: return "Kthjellët me pak vranësira kalimtare."
        case 2: return "Vranësira të pjesshme."
        case 3: return "Vranët. Qielli është plotësisht i mbuluar me vranësira."
        case 45,48: return "Mjegull ose mjegull e ngrirë."
        case 51...55: return "Rigë shiu e lehtë deri mesatare."
        case 61...65: return "Shi i lehtë deri i dendur."
        case 80...82: return "Rrebeshe shiu mesatare deri të forta."
        case 95: return "Shtrëngatë me vetëtima me intensitet të lehtë ose mesatar."
        default: return "Kushte të ndryshueshme vranësirash dhe reshjesh."
        }
    }
}

// MARK: - Humidity Detail

struct HumidityDetailView: View {
    let cur: CurrentConditions
    var dewPoint: Double { cur.temperature - ((100 - Double(cur.humidity)) / 5.0) }
    var comfort: (label: String, color: Color, detail: String) {
        switch cur.humidity {
        case 0..<25:  return ("Shumë e Thatë",  .yellow, "Lëkura dhe fyti mund të ndihen të thatë. Rrezik për elektricitet statik.")
        case 25..<40: return ("E Thatë",        .yellow, "Lagështi e ulët. Komode për shumicën, por disa mund të kenë lëkurë të thatë.")
        case 40..<55: return ("Komode",         .green,  "Nivel ideal. Shumica e njerëzve ndihen komodë në këtë lagështi.")
        case 55..<65: return ("Pak e Lagësht",   .cyan,   "Lagështi pak e ndjeshme. Në përgjithësi mbetet komode.")
        case 65..<75: return ("Mesatarisht e Lagësht",.blue, "Ndihet ngjitëse. Djersitja është më pak efektive për t'ju ftohur.")
        default:      return ("Shumë e Lagësht", Color(red:0.2,green:0.4,blue:1), "Ajër i rëndë. Rrezik për myk dhe diskomfort jashtë.")
        }
    }
    var body: some View {
        VStack(spacing: 12) {
            DetailSection(title: "Detajet e Lagështisë", systemImage: "humidity") {
                DetailRow("Lagështia Relative", "\(cur.humidity)%")
                Divider().background(.white.opacity(0.1))
                DetailRow("Pika e Vesës", "\(String(format:"%.1f",dewPoint))°C")
                Divider().background(.white.opacity(0.1))
                DetailRow("Niveli i Komfortit", comfort.label, color: comfort.color)
            }
            DetailSection(title: "Çfarë do të thotë", systemImage: "figure.stand") {
                Text(comfort.detail).font(.subheadline).foregroundStyle(.white.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
            }
            DetailSection(title: "Shkalla e Lagështisë", systemImage: "chart.bar.fill") {
                VStack(spacing: 6) {
                    ForEach([
                        (0..<25,   "Shumë e Thatë",   Color.yellow),
                        (25..<40,  "E Thatë",         Color.yellow.opacity(0.7)),
                        (40..<55,  "Komode",          Color.green),
                        (55..<65,  "Pak e Lagësht",   Color.cyan),
                        (65..<75,  "Mesatarisht e Lagësht",Color.blue),
                        (75..<101, "Shumë e Lagësht",  Color(red:0.3,green:0.5,blue:1)),
                    ], id: \.1) { range, label, color in
                        let isActive = range.contains(cur.humidity)
                        let rangeStr: String = {
                            if range.lowerBound == 0 { return "< 25%" }
                            if range.lowerBound == 75 { return "> 75%" }
                            return "\(range.lowerBound)–\(range.upperBound)%"
                        }()
                        HStack {
                            Text(rangeStr)
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.5))
                                .frame(width: 70, alignment: .leading)
                            Text(label)
                                .font(.subheadline.bold())
                                .foregroundStyle(color)
                            Spacer()
                            if isActive {
                                Text("Aktive")
                                    .font(.caption.bold())
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(color.opacity(0.4))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
            }
            DetailSection(title: "Pika e Vesës", systemImage: "drop") {
                Text("Pika e vesës (\(String(format:"%.1f",dewPoint))°C) është temperatura në të cilën ajri ngopet dhe formohet vesa. Mbi 18°C ndihet diskomfort dhe mbytës; nën 10°C ndihet ajër shumë i thatë.")
                    .font(.caption).foregroundStyle(.white.opacity(0.55))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Wind Detail

struct WindDetailView: View {
    let cur: CurrentConditions
    var beaufort: (Int, String) {
        switch cur.windSpeed {
        case 0..<1:   return (0, "Qetësi — tymi ngrihet vertikalisht")
        case 1..<6:   return (1, "Ajër i lehtë — tymi lëviz pakëz")
        case 6..<12:  return (2, "Erë e lehtë — gjethet shushutijnë")
        case 12..<20: return (3, "Erë e butë — flamujt lëvizin lehtë")
        case 20..<29: return (4, "Erë mesatare — degët e vogla lëvizin")
        case 29..<39: return (5, "Erë e freskët — pemët e vogla lëkunden")
        case 39..<50: return (6, "Erë e fortë — degët e mëdha lëvizin")
        case 50..<62: return (7, "Stuhi e lehtë — ecja është e vështirë")
        case 62..<75: return (8, "Stuhi — thyehen degët e pemëve")
        default:      return (9, "Stuhi e fortë — dëmtohen çatitë")
        }
    }
    var gustRatio: String {
        let r = cur.windGusts / max(cur.windSpeed, 1)
        if r > 2.0 { return "Me shumë hove — hovet janë më shumë se dyfishi i shpejtësisë mesatare" }
        if r > 1.5 { return "Me hove — pritet variacion i ndjeshëm i shpejtësisë" }
        return "Mjaft e qëndrueshme — hovet janë afër shpejtësisë mesatare"
    }
    func fullCardinal(_ deg: Int) -> String {
        ["Veriu","Verilindja","Lindja","Juglindja","Jugu","Jugperëndimi","Perëndimi","Veriperëndimi"][Int((Double(deg)+22.5)/45.0)%8]
    }
    var body: some View {
        VStack(spacing: 12) {
            DetailSection(title: "Matjet e Erës", systemImage: "wind") {
                DetailRow("Shpejtësia mesatare", "\(String(format:"%.1f",cur.windSpeed)) km/h")
                Divider().background(.white.opacity(0.1))
                DetailRow("Hove ere", "\(String(format:"%.1f",cur.windGusts)) km/h")
                Divider().background(.white.opacity(0.1))
                DetailRow("Drejtimi", "\(cur.windDirection)° \(fullCardinal(cur.windDirection))")
            }
            DetailSection(title: "Shkalla Beaufort", systemImage: "gauge.medium") {
                HStack(spacing: 12) {
                    ZStack {
                        Circle().stroke(.white.opacity(0.15), lineWidth: 4).frame(width: 52, height: 52)
                        Text("\(beaufort.0)").font(.system(size: 22, weight: .bold)).foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Forca \(beaufort.0)").font(.headline).foregroundStyle(.white)
                        Text(beaufort.1).font(.caption).foregroundStyle(.white.opacity(0.6))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            DetailSection(title: "Analiza e Hoveve", systemImage: "arrow.up.and.down.and.arrow.left.and.right") {
                Text(gustRatio).font(.subheadline).foregroundStyle(.white.opacity(0.8))
                Divider().background(.white.opacity(0.1))
                Text("Hovet e erës janë goditje të shkurtra të fuqishme ere (< 20 s) që mund të duken më të forta se shpejtësia mesatare.")
                    .font(.caption).foregroundStyle(.white.opacity(0.55))
                    .fixedSize(horizontal: false, vertical: true)
            }
            DetailSection(title: "Origjina e Erës", systemImage: "location.north.fill") {
                Text("Era fryn nga \(fullCardinal(cur.windDirection)) (\(cur.windDirection)°). Era nga veriperëndimi në Tiranë shpesh sjell ajër më të ftohtë dhe më të thatë nga Adriatiku dhe Alpet Shqiptare.")
                    .font(.subheadline).foregroundStyle(.white.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Rain Detail

struct RainDetailView: View {
    let rain: RainInfo
    func intensity(_ mm: Double) -> (String, Color) {
        if mm == 0  { return ("Asnjë",             .white.opacity(0.4)) }
        if mm < 1   { return ("Gjurmë / Shumë e lehtë",.cyan.opacity(0.7)) }
        if mm < 5   { return ("E lehtë",            .cyan) }
        if mm < 15  { return ("Mesatare",         .blue) }
        if mm < 30  { return ("E fortë",            Color(red:0.2,green:0.4,blue:1)) }
        return        ("Shumë e fortë",              .purple)
    }
    var nextRainText: String {
        guard let h = rain.nextRainInHours else { return "Nuk parashikohen reshje shiu për 24 orët e ardhshme." }
        if h == 0 { return "Aktualisht është duke rënë shi." }
        return "Reshjet priten pas rreth \(h) orësh."
    }
    var body: some View {
        VStack(spacing: 12) {
            DetailSection(title: "24 Orët e ardhshme", systemImage: "clock") {
                DetailRow("Mundësia për Shi", "\(Int(rain.probabilityNext24h))%")
                Divider().background(.white.opacity(0.1))
                DetailRow("Sasia e Pritshme", "\(String(format:"%.1f",rain.totalMmNext24h)) mm")
                Divider().background(.white.opacity(0.1))
                let (lbl, col) = intensity(rain.totalMmNext24h)
                DetailRow("Intensiteti", lbl, color: col)
            }
            DetailSection(title: "Koha", systemImage: "timer") {
                Text(nextRainText).font(.subheadline).foregroundStyle(.white.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
            }
            DetailSection(title: "Ndarja Ditore", systemImage: "list.bullet.rectangle") {
                VStack(spacing: 8) {
                    ForEach(Array(rain.dailyForecast.enumerated()), id: \.element.id) { idx, day in
                        if idx > 0 { Divider().background(.white.opacity(0.1)) }
                        let (il, ic) = intensity(day.precipitationMm)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(day.shortDate).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                            HStack {
                                Text("Mundësia").font(.caption).foregroundStyle(.white.opacity(0.55))
                                Spacer()
                                Text("\(day.probabilityPct)%").font(.caption).foregroundStyle(.cyan)
                            }
                            GaugeBar(value: Double(day.probabilityPct)/100.0, color: .cyan)
                            HStack {
                                Text("Sasia").font(.caption).foregroundStyle(.white.opacity(0.55))
                                Spacer()
                                Text("\(String(format:"%.1f",day.precipitationMm)) mm · \(il)").font(.caption).foregroundStyle(ic)
                            }
                            HStack {
                                Text("Era maksimale").font(.caption).foregroundStyle(.white.opacity(0.55))
                                Spacer()
                                Text("\(Int(day.maxWindKph)) km/h").font(.caption).foregroundStyle(.white.opacity(0.7))
                            }
                        }
                    }
                }
            }
            DetailSection(title: "Referenca e Reshjeve", systemImage: "info.circle") {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach([
                        ("< 1 mm",  "Gjurmë — mezi vërehet"),
                        ("1–5 mm",  "E lehtë — pellgjet formohen ngadalë"),
                        ("5–15 mm", "Mesatare — nevojitet çadër"),
                        ("15–30mm", "E fortë — ngarkohet rrjeti i kullimit"),
                        ("> 30 mm", "Shumë e fortë — rrezik përmbytjeje"),
                    ], id: \.0) { amount, desc in
                        HStack(alignment: .top) {
                            Text(amount).font(.caption).foregroundStyle(.cyan).frame(width: 64, alignment: .leading)
                            Text(desc).font(.caption).foregroundStyle(.white.opacity(0.55))
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Air Quality Detail

struct AirQualityDetailView: View {
    let aq: AirQuality
    var aqiColor: Color {
        switch aq.europeanAqi {
        case ...20: return .green; case ...40: return .yellow
        case ...60: return .orange; case ...80: return Color(red:1,green:0.3,blue:0.1)
        default: return .red }
    }
    var healthRec: String {
        switch aq.europeanAqi {
        case ...20: return "Ideale. Nuk nevojiten masa paraprake. Shijoni aktivitetet jashtë."
        case ...40: return "E pranueshme. Personat e ndjeshëm mund të kufizojnë daljet e gjata jashtë."
        case ...60: return "Mesatare. Grupet e ndjeshme duhet të reduktojnë daljet jashtë."
        case ...80: return "E dobët. Çdokush duhet të reduktojë aktivitetet e gjata jashtë."
        default:    return "Shumë e dobët. Shmangni daljet jashtë, mbani dritaret e mbyllura."
        }
    }
    var body: some View {
        VStack(spacing: 12) {
            DetailSection(title: "Matjet Aktuale", systemImage: "aqi.medium") {
                DetailRow("AQI Evropian", "\(aq.europeanAqi) — \(aq.label)", color: aqiColor)
                Divider().background(.white.opacity(0.1))
                DetailRow("PM2.5", "\(String(format:"%.1f",aq.pm2_5)) µg/m³")
                Divider().background(.white.opacity(0.1))
                DetailRow("PM10",  "\(String(format:"%.1f",aq.pm10)) µg/m³")
            }
            DetailSection(title: "Rekomandimi për Shëndetin", systemImage: "heart.text.square") {
                Text(healthRec).font(.subheadline).foregroundStyle(.white.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
            }
            DetailSection(title: "Krahasimi me OBSH", systemImage: "globe") {
                let over = aq.pm2_5 - 15.0
                Text(over <= 0 ? "PM2.5 nën udhëzimin e OBSH-së për 24h (15 µg/m³) ✓"
                               : "\(String(format:"%.1f",over)) µg/m³ mbi udhëzimin e OBSH-së për 24h")
                    .font(.subheadline).foregroundStyle(.white.opacity(0.8))
                Divider().background(.white.opacity(0.1))
                Text("OBSH vjetore PM2.5: 5 µg/m³\nOBSH 24-orëshe PM2.5: 15 µg/m³")
                    .font(.caption).foregroundStyle(.white.opacity(0.5))
            }
            DetailSection(title: "Shkalla e AQI-së Evropiane", systemImage: "chart.bar.doc.horizontal") {
                VStack(spacing: 6) {
                    ForEach([
                        (0,  20,  "Shkëlqyeshëm",   Color.green),
                        (21, 40,  "E pranueshme",     Color.yellow),
                        (41, 60,  "Mesatare",       Color.orange),
                        (61, 80,  "Dobët",          Color(red:1,green:0.3,blue:0.1)),
                        (81, 100, "Shumë dobët",    Color.red),
                        (101,999, "Jashtëzakonisht dobët", Color.purple),
                    ], id: \.2) { low, high, label, color in
                        let isActive = aq.europeanAqi >= low && (high == 999 ? aq.europeanAqi >= low : aq.europeanAqi <= high)
                        HStack {
                            Text(high == 999 ? "\(low)+" : "\(low)–\(high)")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.5))
                                .frame(width: 70, alignment: .leading)
                            Text(label)
                                .font(.subheadline.bold())
                                .foregroundStyle(color)
                            Spacer()
                            if isActive {
                                Text("Aktive")
                                    .font(.caption.bold())
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(color.opacity(0.4))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Hazards Detail

struct HazardsDetailView: View {
    let disasters: Disasters
    let cur: CurrentConditions
    let earthquakes: [EarthquakeEvent]

    func levelColor(_ l: String) -> Color {
        switch l { case "Minimal","Low","I ulët": return .green; case "Moderate","Mesatar": return .yellow
        case "High","I lartë": return .orange; default: return .red } // Ekstrem
    }

    func formatEventTime(_ ms: Int64) -> String {
        let date = Date(timeIntervalSince1970: Double(ms) / 1000.0)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "sq_AL")
        formatter.dateFormat = "d MMM, HH:mm"
        return formatter.string(from: date)
    }

    var body: some View {
        VStack(spacing: 12) {
            DetailSection(title: "Rreziku i Përmbytjes", systemImage: "cloud.heavyrain.fill") {
                HStack {
                    Text(disasters.flood.level).font(.title3.bold()).foregroundStyle(levelColor(disasters.flood.level))
                    Spacer()
                    Image(systemName: disasters.flood.icon).font(.title3).foregroundStyle(levelColor(disasters.flood.level))
                }
                Divider().background(.white.opacity(0.1))
                Text(disasters.flood.description).font(.subheadline).foregroundStyle(.white.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)
                Divider().background(.white.opacity(0.1))
                Text("Bazuar në: reshjet \(String(format:"%.1f",cur.precipitation)) mm tani, sasia e 24h dhe mundësia për shi.")
                    .font(.caption).foregroundStyle(.white.opacity(0.5)).fixedSize(horizontal: false, vertical: true)
            }
            DetailSection(title: "Konteksti i Përmbytjeve — Tiranë", systemImage: "map") {
                Text("Lumi Lana kalon përmes Tiranës dhe ka një histori përmbytjesh të shpejta. Përmbytjet e shpejta nga pusetat mund të ndodhin kur reshjet kalojnë 20 mm në më pak se 1 orë.")
                    .font(.caption).foregroundStyle(.white.opacity(0.55)).fixedSize(horizontal: false, vertical: true)
            }
            DetailSection(title: "Rreziku i Zjarrit", systemImage: "flame.fill") {
                HStack {
                    Text(disasters.fire.level).font(.title3.bold()).foregroundStyle(levelColor(disasters.fire.level))
                    Spacer()
                    Image(systemName: disasters.fire.icon).font(.title3).foregroundStyle(levelColor(disasters.fire.level))
                }
                Divider().background(.white.opacity(0.1))
                Text(disasters.fire.description).font(.subheadline).foregroundStyle(.white.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)
                Divider().background(.white.opacity(0.1))
                Text("Faktorët: \(String(format:"%.1f",cur.temperature))°C · \(cur.humidity)% lagështi · \(String(format:"%.1f",cur.windSpeed)) km/h erë")
                    .font(.caption).foregroundStyle(.white.opacity(0.5))
            }
            DetailSection(title: "Tërmetet e Fundit (Rreziqet Sizmike)", systemImage: "waveform.path.ecg") {
                if earthquakes.isEmpty {
                    Text("Nuk u gjet asnjë tërmet i regjistruar në rreze prej 400 km kohët e fundit.")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.6))
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(earthquakes.prefix(5)) { eq in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("\(String(format: "%.1f", eq.magnitude)) Rihter")
                                        .font(.subheadline.bold())
                                        .foregroundStyle(eq.magnitude >= 5.0 ? .red : eq.magnitude >= 4.0 ? .orange : .yellow)
                                    
                                    Spacer()
                                    
                                    Text(formatEventTime(eq.time))
                                        .font(.caption2)
                                        .foregroundStyle(.white.opacity(0.5))
                                }
                                
                                Text(eq.place)
                                    .font(.footnote)
                                    .foregroundStyle(.white.opacity(0.8))
                                
                                HStack {
                                    Text("\(Int(eq.distance.rounded())) km larg gjimnazit")
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.65))
                                    
                                    Spacer()
                                    
                                    if eq.isDeep && eq.magnitude >= 4.0 {
                                        Text("Shkundje e fortë")
                                            .font(.caption2.bold())
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(.orange.opacity(0.4))
                                            .clipShape(Capsule())
                                    } else if eq.isFelt {
                                        Text("Ndjerë në Tiranë")
                                            .font(.caption2.bold())
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(.yellow.opacity(0.35))
                                            .clipShape(Capsule())
                                    } else {
                                        Text("E papërfillshme")
                                            .font(.caption2)
                                            .foregroundStyle(.white.opacity(0.45))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(.white.opacity(0.08))
                                            .clipShape(Capsule())
                                    }
                                }
                                
                                Divider().background(.white.opacity(0.06)).padding(.top, 4)
                            }
                        }
                        
                        Text("Shënim: Aplikacioni ju njofton vetëm nëse tërmeti është mag. >= 4.0 dhe gjimnazi ndodhet në rrezen e fortë (inner 40% e rrezes së perceptimit të llogaritur me formulën e McCue: Rp = e^(M/1.01 - 0.13) km).")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.45))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            DetailSection(title: "Numrat e Urgjencës", systemImage: "phone.fill") {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach([
                        ("🚒", "Zjarrfikësja", "128"),
                        ("🚑", "Ambulanca", "127"),
                        ("🚔", "Policia", "129"),
                        ("🆘", "Emergjenca Kombëtare", "112")
                    ], id: \.2) { emoji, label, number in
                        HStack {
                            Button(action: {
                                if let url = URL(string: "tel://\(number)") {
                                    UIApplication.shared.open(url)
                                }
                            }) {
                                HStack(spacing: 8) {
                                    Text(emoji)
                                    Text(label)
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.white.opacity(0.85))
                                    Spacer()
                                    Text(number)
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.white)
                                }
                            }
                            .buttonStyle(PressableGlassButtonStyle())
                            
                            Spacer().frame(width: 12)
                            
                            Button(action: {
                                if let url = URL(string: "tel://\(number)") {
                                    UIApplication.shared.open(url)
                                }
                            }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "phone.fill")
                                            .font(.caption2)
                                        Text("Telefono")
                                            .font(.caption.bold())
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(.green.opacity(0.35))
                                    .foregroundStyle(.white)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(PressableGlassButtonStyle())
                        }
                        if number != "112" {
                            Divider().background(.white.opacity(0.1))
                        }
                    }
                }
            }
            
            HStack {
                Spacer()
                Link(destination: URL(string: "https://gist.github.com/ExplodingWater/5de2329d88cf1bcd2cee8127bb88baa1")!) {
                    HStack(spacing: 4) {
                        Image(systemName: "lock.shield.fill")
                        Text("Politika e Privatësisë")
                    }
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(.white.opacity(0.06))
                    .clipShape(Capsule())
                }
                .buttonStyle(PressableGlassButtonStyle())
                Spacer()
            }
            .padding(.top, 4)
        }
    }
}

// MARK: - Forecast Detail

struct ForecastDetailView: View {
    let rain: RainInfo
    func intensity(_ mm: Double) -> (String, Color) {
        if mm == 0  { return ("Asnjë",    .white.opacity(0.4)) }
        if mm < 1   { return ("Gjurmë",   .cyan.opacity(0.7)) }
        if mm < 5   { return ("E lehtë",   .cyan) }
        if mm < 15  { return ("Mesatare",.blue) }
        return        ("E fortë", Color(red:0.2,green:0.4,blue:1))
    }
    var body: some View {
        VStack(spacing: 12) {
            ForEach(rain.dailyForecast) { day in
                let (il, ic) = intensity(day.precipitationMm)
                DetailSection(title: day.shortDate, systemImage: "calendar.day.timeline.left") {
                    VStack(spacing: 8) {
                        HStack {
                            Text("Mundësia e shiut").font(.subheadline).foregroundStyle(.white.opacity(0.6))
                            Spacer()
                            Text("\(day.probabilityPct)%").font(.subheadline.bold()).foregroundStyle(.cyan)
                        }
                        GaugeBar(value: Double(day.probabilityPct)/100.0, color: .cyan)
                        Divider().background(.white.opacity(0.1))
                        DetailRow("Reshjet", "\(String(format:"%.1f",day.precipitationMm)) mm", color: ic)
                        DetailRow("Intensiteti", il, color: ic)
                        Divider().background(.white.opacity(0.1))
                        DetailRow("Era maksimale", "\(Int(day.maxWindKph)) km/h")
                        GaugeBar(value: day.maxWindKph / 80.0, color: .white.opacity(0.6))
                    }
                }
            }
            DetailSection(title: "Burimi i të Dhënave", systemImage: "server.rack") {
                Text("Open-Meteo (ECMWF) · gjer. gjeogr. 41.3372°V, gjat. gjeogr. 19.8328°L · Gjimnazi Andon Zako Çajupi, Tiranë · Përditësohet çdo orë.")
                    .font(.caption).foregroundStyle(.white.opacity(0.5))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Redefine glassEffect for custom corner radius (22pt) for modern iOS squircle look
extension View {
    func glassEffect() -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(.white.opacity(0.06))
                    .background(
                        RoundedRectangle(cornerRadius: 22)
                            .stroke(.white.opacity(0.12), lineWidth: 1)
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 22))
    }
}

// MARK: - Custom Button Styles for Press and Enlarge / Shine animation
struct CircularPressableGlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 1.08 : 1.0)
            .brightness(configuration.isPressed ? 0.08 : 0.0)
            .overlay(
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.25), .clear, .white.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .blendMode(.plusLighter)
                    .opacity(configuration.isPressed ? 1.0 : 0.0)
            )
            .shadow(color: Color.white.opacity(configuration.isPressed ? 0.35 : 0.0), radius: configuration.isPressed ? 12 : 0)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct PressableGlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 1.08 : 1.0)
            .brightness(configuration.isPressed ? 0.08 : 0.0)
            .overlay(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.25), .clear, .white.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .blendMode(.plusLighter)
                    .opacity(configuration.isPressed ? 1.0 : 0.0)
            )
            .shadow(color: Color.white.opacity(configuration.isPressed ? 0.35 : 0.0), radius: configuration.isPressed ? 12 : 0)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct GlassCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 1.03 : 1.0)
            .brightness(configuration.isPressed ? 0.06 : 0.0)
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.2), .clear, .white.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .blendMode(.plusLighter)
                    .opacity(configuration.isPressed ? 1.0 : 0.0)
            )
            .shadow(color: Color.blue.opacity(configuration.isPressed ? 0.3 : 0.0), radius: configuration.isPressed ? 15 : 0)
            .animation(.spring(response: 0.25, dampingFraction: 0.65), value: configuration.isPressed)
    }
}
