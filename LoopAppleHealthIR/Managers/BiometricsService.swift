// BiometricsService.swift
// Loop
//
// Observes HealthKit biometrics and publishes a consolidated BiometricsSnapshot
// whenever any of the tracked quantities change.

import Foundation
import HealthKit
import Combine
import os.log

private let log = OSLog(subsystem: "com.loopkit.Loop", category: "BiometricsService")

// MARK: - BiometricsSnapshot

/// A point-in-time reading of all tracked biometric values.
public struct BiometricsSnapshot {
    public var sleepHours: Double?
    public var stepCount: Double?
    public var hrvSDNN: Double?
    public var exerciseMinutes: Double?
    public var heartRate: Double?

    public init(sleepHours: Double? = nil,
                stepCount: Double? = nil,
                hrvSDNN: Double? = nil,
                exerciseMinutes: Double? = nil,
                heartRate: Double? = nil) {
        self.sleepHours = sleepHours
        self.stepCount = stepCount
        self.hrvSDNN = hrvSDNN
        self.exerciseMinutes = exerciseMinutes
        self.heartRate = heartRate
    }
}

// MARK: - Protocol

public protocol BiometricsServiceProtocol: AnyObject {
    var biometricsPublisher: AnyPublisher<BiometricsSnapshot, Never> { get }
}

// MARK: - BiometricsService

/// Fetches and observes five HealthKit types, publishing a new snapshot on any change.
public final class BiometricsService: BiometricsServiceProtocol {

    // MARK: Public

    public var biometricsPublisher: AnyPublisher<BiometricsSnapshot, Never> {
        subject.eraseToAnyPublisher()
    }

    // MARK: Private

    private let store = HKHealthStore()
    private let subject = PassthroughSubject<BiometricsSnapshot, Never>()
    /// Serial queue that serialises all reads/writes of `snapshot`.
    private let snapshotQueue = DispatchQueue(label: "com.loopkit.Loop.BiometricsService.snapshot")
    private var snapshot = BiometricsSnapshot()
    private var observerQueries: [HKObserverQuery] = []

    // MARK: - HK Types

    private let sleepType      = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
    private let stepType       = HKQuantityType.quantityType(forIdentifier: .stepCount)!
    private let hrvType        = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
    private let exerciseType   = HKQuantityType.quantityType(forIdentifier: .appleExerciseTime)!
    private let heartRateType  = HKQuantityType.quantityType(forIdentifier: .heartRate)!

    // MARK: - Init

    public init() {
        guard HKHealthStore.isHealthDataAvailable() else {
            os_log(.info, log: log, "HealthKit not available on this device.")
            return
        }
        requestPermissions()
    }

    // MARK: - Permissions

    private func requestPermissions() {
        let readTypes: Set<HKObjectType> = [
            sleepType, stepType, hrvType, exerciseType, heartRateType
        ]
        store.requestAuthorization(toShare: nil, read: readTypes) { [weak self] granted, error in
            guard let self = self else { return }
            if let error = error {
                os_log(.error, log: log, "HK authorization error: %{public}@", error.localizedDescription)
                return
            }
            guard granted else {
                os_log(.info, log: log, "HK authorization not fully granted.")
                return
            }
            self.setupObservers()
            self.fetchAll()
        }
    }

    // MARK: - Observers

    private func setupObservers() {
        let types: [HKObjectType] = [sleepType, stepType, hrvType, exerciseType, heartRateType]

        for sampleType in types {
            let query = HKObserverQuery(sampleType: sampleType as! HKSampleType,
                                        predicate: nil) { [weak self] _, completionHandler, error in
                if let error = error {
                    os_log(.error, log: log, "HK observer error for %{public}@: %{public}@",
                           sampleType.identifier, error.localizedDescription)
                    completionHandler()
                    return
                }
                self?.fetchAll()
                completionHandler()
            }
            store.execute(query)
            observerQueries.append(query)

            store.enableBackgroundDelivery(for: sampleType as! HKSampleType,
                                           frequency: .immediate) { success, error in
                if let error = error {
                    os_log(.error, log: log,
                           "Background delivery error for %{public}@: %{public}@",
                           sampleType.identifier, error.localizedDescription)
                }
            }
        }
    }

    // MARK: - Fetching

    private func fetchAll() {
        let group = DispatchGroup()

        group.enter()
        fetchSleep { [weak self] hours in
            guard let self = self else { group.leave(); return }
            self.snapshotQueue.async {
                self.snapshot.sleepHours = hours
                group.leave()
            }
        }

        group.enter()
        fetchQuantitySum(type: stepType, unit: .count()) { [weak self] value in
            guard let self = self else { group.leave(); return }
            self.snapshotQueue.async {
                self.snapshot.stepCount = value
                group.leave()
            }
        }

        group.enter()
        fetchLatestQuantity(type: hrvType, unit: HKUnit.secondUnit(with: .milli)) { [weak self] value in
            guard let self = self else { group.leave(); return }
            self.snapshotQueue.async {
                self.snapshot.hrvSDNN = value
                group.leave()
            }
        }

        group.enter()
        fetchQuantitySum(type: exerciseType, unit: .minute()) { [weak self] value in
            guard let self = self else { group.leave(); return }
            self.snapshotQueue.async {
                self.snapshot.exerciseMinutes = value
                group.leave()
            }
        }

        group.enter()
        fetchLatestQuantity(type: heartRateType,
                            unit: HKUnit.count().unitDivided(by: .minute())) { [weak self] value in
            guard let self = self else { group.leave(); return }
            self.snapshotQueue.async {
                self.snapshot.heartRate = value
                group.leave()
            }
        }

        // snapshotQueue is used as the notify target so the final read of
        // `snapshot` is also serialised, then we hop to main for publishing.
        group.notify(queue: snapshotQueue) { [weak self] in
            guard let self = self else { return }
            let current = self.snapshot
            DispatchQueue.main.async {
                self.subject.send(current)
            }
        }
    }

    /// Fetch sum of a quantity type over the last 24 hours.
    private func fetchQuantitySum(type: HKQuantityType,
                                  unit: HKUnit,
                                  completion: @escaping (Double?) -> Void) {
        let predicate = last24hPredicate()
        let query = HKStatisticsQuery(quantityType: type,
                                      quantitySamplePredicate: predicate,
                                      options: .cumulativeSum) { _, result, error in
            if let error = error {
                os_log(.error, log: log,
                       "Statistics query error for %{public}@: %{public}@",
                       type.identifier, error.localizedDescription)
                completion(nil)
                return
            }
            completion(result?.sumQuantity()?.doubleValue(for: unit))
        }
        store.execute(query)
    }

    /// Fetch the most recent sample of a quantity type.
    private func fetchLatestQuantity(type: HKQuantityType,
                                     unit: HKUnit,
                                     completion: @escaping (Double?) -> Void) {
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(sampleType: type,
                                  predicate: nil,
                                  limit: 1,
                                  sortDescriptors: [sort]) { _, samples, error in
            if let error = error {
                os_log(.error, log: log,
                       "Sample query error for %{public}@: %{public}@",
                       type.identifier, error.localizedDescription)
                completion(nil)
                return
            }
            let sample = samples?.first as? HKQuantitySample
            completion(sample?.quantity.doubleValue(for: unit))
        }
        store.execute(query)
    }

    /// Fetch total InBed sleep hours in the last 24 hours.
    private func fetchSleep(completion: @escaping (Double?) -> Void) {
        let predicate = last24hPredicate()
        let query = HKSampleQuery(sampleType: sleepType,
                                  predicate: predicate,
                                  limit: HKObjectQueryNoLimit,
                                  sortDescriptors: nil) { _, samples, error in
            if let error = error {
                os_log(.error, log: log, "Sleep query error: %{public}@", error.localizedDescription)
                completion(nil)
                return
            }
            guard let categorySamples = samples as? [HKCategorySample] else {
                completion(nil)
                return
            }
            let totalSeconds = categorySamples
                .filter { $0.value == HKCategoryValueSleepAnalysis.inBed.rawValue }
                .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
            let hours = totalSeconds / 3600.0
            completion(hours > 0 ? hours : nil)
        }
        store.execute(query)
    }

    // MARK: - Helpers

    private func last24hPredicate() -> NSPredicate {
        let start = Date().addingTimeInterval(-24 * 60 * 60)
        return HKQuery.predicateForSamples(withStart: start, end: nil, options: .strictStartDate)
    }
}

