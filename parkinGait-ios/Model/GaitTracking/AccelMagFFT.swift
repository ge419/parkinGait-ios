//
//  AccelMagFFT.swift
//  parkinGait-ios
//
//  Created by 신창민 on 1/28/25.
//

import Foundation
import Accelerate
import CoreMotion
import simd

class AccelMagFFT: ObservableObject {
    private let METERS_TO_INCHES: Float = 39.3701
    private let ACCEL_THRESHOLD: Float = 10.0
    private let MIN_DELTA_TIME: TimeInterval = 0.5  // Minimum step duration (seconds)
    private let MAX_DELTA_TIME: TimeInterval = 2.0  // Maximum step duration (seconds)
    private let TARGET_STEP_LENGTH: Double = 30.0  // Target step length in inches
    private let CUTOFF_FREQUENCY: Float = 2.0  // Hz (Step frequency typically 1-3 Hz)
    private let SAMPLING_RATE: Float = 10.0  // Hz
    private let WINDOW_SIZE = 128  // Must be a power of 2

    @Published var rawAccelerationData: [(timestamp: TimeInterval, accelMagnitude: Float)] = []
    @Published var filteredAccelerationData: [(timestamp: TimeInterval, accelMagnitude: Float)] = []
    @Published var detectedSteps: [(timestamp: TimeInterval, stepLength: Double)] = []
    @Published var stepCount: Int = 0
    @Published var avgStepLength: Double = 0.0
    @Published var stepVariance: Double = 0.0
    @Published var accuracy: Double = 0.0  // Accuracy compared to TARGET_STEP_LENGTH
    @Published var recommendation: String = "Start Walking to See Analysis"

    private var collectedData: [(timestamp: TimeInterval, accelMagnitude: Float)] = []
    private var fftSetup: vDSP_DFT_Setup?

    // Step detection states
    private var positiveSparkDetected: Bool = false
    private var stepStartTime: TimeInterval?

    init() {
        // Initialize FFT setup once and reuse it
        fftSetup = vDSP_DFT_zop_CreateSetup(nil, vDSP_Length(WINDOW_SIZE), vDSP_DFT_Direction.FORWARD)
        if fftSetup == nil {
            print("FFT Setup failed!")
        }
    }

    deinit {
        if let fftSetup = fftSetup {
            vDSP_DFT_DestroySetup(fftSetup)
        }
    }

    /// **Collects data for processing later (not real-time calculation)**
    func collectData(timestamp: TimeInterval, accel: SIMD3<Float>, quaternion: CMQuaternion) {
        let gravity = getGravity(q: quaternion)
        let ag = projectAccelOnGravity(accel: accel, gravity: gravity) * METERS_TO_INCHES
        let accelMagnitude = length(ag)

        collectedData.append((timestamp, accelMagnitude))
        DispatchQueue.main.async {
            self.rawAccelerationData.append((timestamp, accelMagnitude))
        }
    }

    /// **Process FFT, Filter Noise, and Detect Steps**
    func analyzeSteps() {
        guard collectedData.count >= WINDOW_SIZE else {
            recommendation = "Not enough data to analyze."
            return
        }

        let timestamps = collectedData.map { $0.timestamp }
        var accelMagnitudes = collectedData.map { $0.accelMagnitude }
        let filteredMagnitudes = applyFFTFilter(&accelMagnitudes)

        DispatchQueue.main.async {
            self.filteredAccelerationData = zip(timestamps, filteredMagnitudes).map { ($0, $1) }
            self.detectSteps(timestamps: timestamps, filteredMagnitudes: filteredMagnitudes)
            self.computeStatistics()
        }
    }

    /// **Apply FFT-based Noise Filtering**
    private func applyFFTFilter(_ data: inout [Float]) -> [Float] {
        guard let fftSetup = fftSetup, data.count >= WINDOW_SIZE else {
            print("Warning: Not enough data for FFT.")
            return data
        }

        var realParts = data
        var imaginaryParts = [Float](repeating: 0.0, count: data.count)

        realParts.withUnsafeMutableBufferPointer { realPointer in
            imaginaryParts.withUnsafeMutableBufferPointer { imagPointer in
                vDSP_DFT_Execute(fftSetup, realPointer.baseAddress!, imagPointer.baseAddress!,
                                 realPointer.baseAddress!, imagPointer.baseAddress!)
            }
        }

        // **Remove high-frequency noise**
        let frequencies = (0..<data.count).map { Float($0) * SAMPLING_RATE / Float(data.count) }
        for i in 0..<data.count {
            if frequencies[i] > CUTOFF_FREQUENCY {
                realParts[i] = 0.0
                imaginaryParts[i] = 0.0
            }
        }

        // **Inverse FFT to recover filtered signal**
        vDSP_DFT_Execute(fftSetup, realParts, imaginaryParts, &realParts, &imaginaryParts)

        return realParts
    }

    /// **Detect Steps using Positive/Negative Spark Detection**
    private func detectSteps(timestamps: [TimeInterval], filteredMagnitudes: [Float]) {
        var detectedStepsTemp: [(timestamp: TimeInterval, stepLength: Double)] = []

        for i in 1..<filteredMagnitudes.count {
            let accelMag = filteredMagnitudes[i]

            // **Positive Spark Detection (Step Start)**
            if accelMag > ACCEL_THRESHOLD, !positiveSparkDetected {
                positiveSparkDetected = true
                stepStartTime = timestamps[i]
            }
            // **Negative Spark Detection (Step End)**
            else if accelMag < ACCEL_THRESHOLD, positiveSparkDetected {
                positiveSparkDetected = false

                if let startTime = stepStartTime {
                    let deltaTime = timestamps[i] - startTime

                    if MIN_DELTA_TIME <= deltaTime && deltaTime <= MAX_DELTA_TIME {
                        let stepLength = Double(abs(accelMag - filteredMagnitudes[i - 1])) * Double(METERS_TO_INCHES)  // Convert displacement to inches
                        detectedStepsTemp.append((timestamps[i], stepLength))
                        print("Step Detected: ΔTime = \(deltaTime), Step Length = \(stepLength) inches")
                    }
                    stepStartTime = nil
                }
            }
        }

        detectedSteps = detectedStepsTemp
        stepCount = detectedSteps.count
    }

    /// **Compute Step Statistics (Average, Variance, Accuracy)**
    private func computeStatistics() {
        guard !detectedSteps.isEmpty else {
            recommendation = "No steps detected."
            return
        }

        let stepLengths = detectedSteps.map { $0.stepLength }
        avgStepLength = stepLengths.reduce(0, +) / Double(stepLengths.count)
        stepVariance = stepLengths.map { pow($0 - avgStepLength, 2) }.reduce(0, +) / Double(stepLengths.count)
        accuracy = (1 - abs(avgStepLength - TARGET_STEP_LENGTH) / TARGET_STEP_LENGTH) * 100.0

        recommendation = accuracy >= 90.0 ? "Great! Keep your step length." : (avgStepLength > TARGET_STEP_LENGTH ? "Shorten your steps" : "Increase your steps")

        // **Print results in terminal**
        print("Step Count: \(stepCount)")
        print("Average Step Length: \(avgStepLength) inches")
        print("Step Variance: \(stepVariance)")
        print("Accuracy: \(accuracy)%")
    }

    /// **Gravity vector from quaternion**
    private func getGravity(q: CMQuaternion) -> SIMD3<Float> {
        return SIMD3<Float>(
            2 * (Float(q.w) * Float(q.z) - Float(q.x) * Float(q.y)),
            2 * (Float(q.y) * Float(q.z) + Float(q.w) * Float(q.x)),
            Float(q.w) * Float(q.w) - Float(q.x) * Float(q.x) - Float(q.y) * Float(q.y) + Float(q.z) * Float(q.z)
        )
    }

    /// **Project acceleration onto gravity vector**
    private func projectAccelOnGravity(accel: SIMD3<Float>, gravity: SIMD3<Float>) -> SIMD3<Float> {
        return accel - dot(accel, gravity) * gravity
    }
}
