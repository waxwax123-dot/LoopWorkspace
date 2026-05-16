// BiometricHomePanel.swift
// Loop
//
// Collapsible home-screen panel showing 5 biometric tiles with IR deltas
// and an overall IR multiplier badge.

import SwiftUI
import Combine

// MARK: - Observable wrapper

public final class AppleHealthIRServiceObservable: ObservableObject {

    @Published public private(set) var multiplier: Double = 1.0
    @Published public private(set) var snapshot: BiometricsSnapshot = BiometricsSnapshot()

    private let irService: AppleHealthIRServiceProtocol
    private var cancellables = Set<AnyCancellable>()

    public init(irService: AppleHealthIRServiceProtocol,
                biometricsService: BiometricsServiceProtocol) {
        self.irService = irService

        biometricsService.biometricsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newSnapshot in
                guard let self = self else { return }
                self.snapshot = newSnapshot
                self.irService.update(snapshot: newSnapshot)
                self.multiplier = self.irService.multiplier
            }
            .store(in: &cancellables)
    }

    public func entries(for source: BiometricSource) -> [AppleHealthIREntry] {
        irService.entries.filter { $0.source == source }
    }

    public func irDelta(for source: BiometricSource) -> Double {
        irService.entries
            .filter { $0.source == source }
            .last?.irDeltaPercent ?? 0
    }
}

// MARK: - BiometricHomePanel

public struct BiometricHomePanel: View {

    @ObservedObject var service: AppleHealthIRServiceObservable
    @State private var isExpanded: Bool = true
    @State private var selectedSource: BiometricSource? = nil

    public init(service: AppleHealthIRServiceObservable) {
        self.service = service
    }

    public var body: some View {
        VStack(spacing: 0) {
            headerRow
            if isExpanded {
                tilesGrid
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .sheet(item: $selectedSource) { source in
            BiometricIRDetailView(
                source: source,
                rawValue: rawValue(for: source),
                irDelta: service.irDelta(for: source)
            )
        }
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack {
            Text("Biometrics")
                .font(.headline)

            Spacer()

            multiplierBadge

            Button {
                isExpanded.toggle()
            } label: {
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - Multiplier badge

    private var multiplierBadge: some View {
        let m = service.multiplier
        let color: Color = m < 1.0 ? .green : m > 1.0 ? .orange : .gray
        return Text(String(format: "×%.2f", m))
            .font(.caption.bold())
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .cornerRadius(6)
    }

    // MARK: - Tiles

    private var tilesGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()),
                             GridItem(.flexible())], spacing: 10) {
            tile(source: .steps,    label: "Steps",    value: service.snapshot.stepCount)
            tile(source: .hrv,      label: "HRV",      value: service.snapshot.hrvSDNN)
            tile(source: .sleep,    label: "Sleep",    value: service.snapshot.sleepHours)
            tile(source: .exercise, label: "Exercise", value: service.snapshot.exerciseMinutes)
            bpmTile
        }
    }

    private func tile(source: BiometricSource, label: String, value: Double?) -> some View {
        let delta = service.irDelta(for: source)
        return Button {
            selectedSource = source
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(value.map { source.formatValue($0) } ?? "—")
                    .font(.subheadline.bold())
                    .foregroundColor(.primary)
                    .monospacedDigit()

                deltaLabel(delta)
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.tertiarySystemBackground))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }

    private var bpmTile: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("BPM")
                .font(.caption)
                .foregroundColor(.secondary)

            Text(service.snapshot.heartRate.map { String(format: "%.0f", $0) } ?? "—")
                .font(.subheadline.bold())
                .foregroundColor(.primary)
                .monospacedDigit()

            Text("—")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(8)
    }

    // MARK: - Helpers

    private func deltaLabel(_ delta: Double) -> some View {
        let text = delta == 0 ? "None" : String(format: "%+.0f%%", delta)
        let color: Color = delta > 0 ? .orange : delta < 0 ? .green : .secondary
        return Text(text)
            .font(.caption2.bold())
            .foregroundColor(color)
    }

    private func rawValue(for source: BiometricSource) -> Double? {
        switch source {
        case .sleep:    return service.snapshot.sleepHours
        case .steps:    return service.snapshot.stepCount
        case .hrv:      return service.snapshot.hrvSDNN
        case .exercise: return service.snapshot.exerciseMinutes
        }
    }
}

// MARK: - BiometricSource: Identifiable (for sheet item binding)

extension BiometricSource: Identifiable {
    public var id: String { rawValue }
}
