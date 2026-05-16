// AppleHealthIREntry.swift
// Loop
//
// A single biometric insulin-resistance event stored in a 24-hour rolling window.

import Foundation
import os.log

private let log = OSLog(subsystem: "com.loopkit.Loop", category: "AppleHealthIREntry")

// MARK: - BiometricSource

/// The biometric data source that produced an IR adjustment.
public enum BiometricSource: String, Codable, CaseIterable {
    case sleep
    case steps
    case hrv
    case exercise
}

// MARK: - AppleHealthIREntry

/// One data point linking a biometric reading to the IR delta it produced.
public struct AppleHealthIREntry: Codable, Equatable {

    // MARK: Properties

    public let timestamp: Date
    public let source: BiometricSource

    /// IR delta as a percentage (e.g. +15 = 15% increase in resistance, -8 = 8% improvement).
    public let irDeltaPercent: Double

    /// Human-readable description of the raw value (e.g. "5.2 h sleep").
    public let details: String

    // MARK: Init

    public init(timestamp: Date = Date(),
                source: BiometricSource,
                irDeltaPercent: Double,
                details: String) {
        self.timestamp = timestamp
        self.source = source
        self.irDeltaPercent = irDeltaPercent
        self.details = details
    }

    // MARK: - Persistence (24-hour rolling window)

    private static let defaultsKey = "AppleHealthIREntries"
    private static let windowDuration: TimeInterval = 24 * 60 * 60

    /// Returns all entries from the last 24 hours, sorted ascending by timestamp.
    public static func allEntries() -> [AppleHealthIREntry] {
        return loadFromDefaults()
    }

    /// Appends a new entry and trims entries older than 24 hours.
    public static func append(_ entry: AppleHealthIREntry) {
        var existing = loadFromDefaults()
        existing.append(entry)
        let cutoff = Date().addingTimeInterval(-windowDuration)
        existing = existing.filter { $0.timestamp >= cutoff }
        save(existing)
    }

    // MARK: - Private helpers

    private static func loadFromDefaults() -> [AppleHealthIREntry] {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else {
            return []
        }
        do {
            let all = try JSONDecoder().decode([AppleHealthIREntry].self, from: data)
            let cutoff = Date().addingTimeInterval(-windowDuration)
            return all.filter { $0.timestamp >= cutoff }.sorted { $0.timestamp < $1.timestamp }
        } catch {
            os_log(.fault, log: log,
                   "Failed to decode AppleHealthIREntries: %{public}@",
                   error.localizedDescription)
            return []
        }
    }

    private static func save(_ entries: [AppleHealthIREntry]) {
        guard let data = try? JSONEncoder().encode(entries) else {
            os_log(.error, log: log, "Failed to encode AppleHealthIREntries for save.")
            return
        }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }
}
