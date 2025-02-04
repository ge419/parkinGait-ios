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

class AccelMagFFT {
    private let METERS_TO_INCHES: Float = 39.3701
    private let ACCEL_THRESHOLD: Float = 10.0
    private let MIN_DELTA_TIME: TimeInterval = 0.5  // Minimum step duration (seconds)
    private let MAX_DELTA_TIME: TimeInterval = 2.0  // Maximum step duration (seconds)
    private let TARGET_STEP_LENGTH: Double = 30.0  // Target step length in inches
    private let CUTOFF_FREQUENCY: Float = 2.0  // Hz (Step frequency typically 1-3 Hz)
    private let SAMPLING_RATE: Float = 10.0  // Hz
    private let WINDOW_SIZE = 128  // Must be a power of 2

    @Published var rawAccelerationData: [AccelFFTRecord] = []
    @Published var filteredAccelerationData: [AccelFFTRecord] = []
    @Published var detectedSteps: [AccelFFTRecord] = []
    @Published var stepCount: Int = 0
    @Published var avgStepLength: Double = 0.0
    @Published var stepVariance: Double = 0.0
    @Published var accuracy: Double = 0.0  // Accuracy compared to TARGET_STEP_LENGTH
    @Published var recommendation: String = "Start Walking to See Analysis"

    private var collectedData: [AccelFFTRecord] = []
    private var fftSetup: vDSP_DFT_Setup?
    
    // Step detection states
    private var positiveSparkDetected: Bool = false
    private var stepStartTime: TimeInterval?

    init() {
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

    /// **Collects acceleration and gyroscope data (raw)**
    func collectData(timestamp: TimeInterval, accel: SIMD3<Float>, gyro: SIMD3<Float>, quaternion: CMQuaternion) {
        let gravity = getGravity(q: quaternion)
        let ag = projectAccelOnGravity(accel: accel, gravity: gravity) * METERS_TO_INCHES
        let accelMagnitude = length(ag)

        let record = AccelFFTRecord(
            timestamp: timestamp,
            accelX: Double(ag.x),
            accelY: Double(ag.y),
            accelZ: Double(ag.z),
            accelMagnitude: Double(accelMagnitude),
            gyroX: Double(gyro.x),
            gyroY: Double(gyro.y),
            gyroZ: Double(gyro.z),
            filteredAccelMagnitude: nil, // Will be computed later
            stepDetected: false,
            stepLength: nil
        )

        collectedData.append(record)
        DispatchQueue.main.async {
            self.rawAccelerationData.append(record)
        }
    }

    /// **Process FFT, Filter Noise, and Detect Steps**
    func analyzeSteps() {
        guard collectedData.count >= WINDOW_SIZE else {
            recommendation = "Not enough data to analyze."
            return
        }

        let timestamps = collectedData.map { $0.timestamp }
        var accelMagnitudes = collectedData.map { Float($0.accelMagnitude) }
        let filteredMagnitudes = applyFFTFilter(&accelMagnitudes)

        for i in 0..<collectedData.count {
            collectedData[i].filteredAccelMagnitude = Double(filteredMagnitudes[i])
        }

        DispatchQueue.main.async {
            self.filteredAccelerationData = self.collectedData
            self.detectSteps()
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

        let frequencies = (0..<data.count).map { Float($0) * SAMPLING_RATE / Float(data.count) }
        for i in 0..<data.count {
            if frequencies[i] > CUTOFF_FREQUENCY {
                realParts[i] = 0.0
                imaginaryParts[i] = 0.0
            }
        }

        vDSP_DFT_Execute(fftSetup, realParts, imaginaryParts, &realParts, &imaginaryParts)
        return realParts
    }

    /// **Detect Steps using Positive/Negative Spark Detection**
    private func detectSteps() {
        var detectedStepsTemp: [AccelFFTRecord] = []

        for i in 1..<collectedData.count {
            let accelMag = collectedData[i].filteredAccelMagnitude ?? collectedData[i].accelMagnitude

            // **Positive Spark Detection (Step Start)**
            if accelMag > Double(ACCEL_THRESHOLD), !positiveSparkDetected {
                positiveSparkDetected = true
                stepStartTime = collectedData[i].timestamp
            }
            // **Negative Spark Detection (Step End)**
            else if accelMag < Double(ACCEL_THRESHOLD), positiveSparkDetected {
                positiveSparkDetected = false

                if let startTime = stepStartTime {
                    let deltaTime = collectedData[i].timestamp - startTime

                    if MIN_DELTA_TIME <= deltaTime && deltaTime <= MAX_DELTA_TIME {
                        let stepLength = Double(abs(accelMag - (collectedData[i - 1].filteredAccelMagnitude ?? collectedData[i - 1].accelMagnitude))) * Double(METERS_TO_INCHES)

                        collectedData[i].stepDetected = true
                        collectedData[i].stepLength = stepLength
                        detectedStepsTemp.append(collectedData[i])
                    }
                    stepStartTime = nil
                }
            }
        }

        detectedSteps = detectedStepsTemp
        stepCount = detectedSteps.count
    }
    
    func exportGaitData(fileName: String) -> URL? {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        var csvText = "Timestamp,AccelX,AccelY,AccelZ,AccelMagnitude,FilteredAccelMag, GyroX,GyroY,GyroZ,StepDetected,StepLength\n"

        for record in collectedData {
            csvText.append("\(record.timestamp),\(record.accelX),\(record.accelY),\(record.accelZ),\(record.accelMagnitude),\(String(describing: record.filteredAccelMagnitude)), \(record.gyroX),\(record.gyroY),\(record.gyroZ),\(record.stepDetected ? "Yes" : "No"),\(record.stepLength != nil ? String(record.stepLength!) : "")\n")
        }

        do {
            try csvText.write(to: path, atomically: true, encoding: .utf8)
            return path
        } catch {
            print("Failed to write CSV: \(error.localizedDescription)")
            return nil
        }
    }

    /// **Compute Step Statistics**
    private func computeStatistics() {
        guard !detectedSteps.isEmpty else {
            recommendation = "No steps detected."
            return
        }

        let stepLengths = detectedSteps.map { $0.stepLength ?? 0 }
        avgStepLength = stepLengths.reduce(0, +) / Double(stepLengths.count)
        stepVariance = stepLengths.map { pow($0 - avgStepLength, 2) }.reduce(0, +) / Double(stepLengths.count)
        accuracy = (1 - abs(avgStepLength - TARGET_STEP_LENGTH) / TARGET_STEP_LENGTH) * 100.0

        recommendation = accuracy >= 90.0 ? "Great! Keep your step length." : (avgStepLength > TARGET_STEP_LENGTH ? "Shorten your steps" : "Increase your steps")
    }
    private func getGravity(q: CMQuaternion) -> SIMD3<Float> {
        let r0 = 2 * Float(q.w * q.z - q.x * q.y)
        let r1 = 2 * Float(q.y * q.z + q.w * q.x)
        let r2 = Float(q.w * q.w - q.x * q.x - q.y * q.y + q.z * q.z)
        return SIMD3<Float>(r0, r1, r2)
    }

    private func projectAccelOnGravity(accel: SIMD3<Float>, gravity: SIMD3<Float>) -> SIMD3<Float> {
        return accel - dot(accel, gravity) * gravity
    }
}

/// **Data Model for Gait Analysis**
struct AccelFFTRecord {
    let timestamp: TimeInterval
    let accelX: Double
    let accelY: Double
    let accelZ: Double
    let accelMagnitude: Double
    let gyroX: Double
    let gyroY: Double
    let gyroZ: Double
    var filteredAccelMagnitude: Double?
    var stepDetected: Bool
    var stepLength: Double?
}
