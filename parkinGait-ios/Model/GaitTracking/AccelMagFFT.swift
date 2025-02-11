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
    private let MIN_DELTA_TIME: Float = 0.5  // Minimum step duration (seconds)
    private let MAX_DELTA_TIME: Float = 2.0  // Maximum step duration (seconds)
    private let TARGET_STEP_LENGTH: Double = 30.0  // Target step length in inches
    private let CUTOFF_FREQUENCY: Float = 2.0  // Hz (Step frequency typically 1-3 Hz)
    private let SAMPLING_RATE: Float = 10.0  // Hz
    private let WINDOW_SIZE = 128  // Must be a power of 2
    private let WINDOW_SIZE_THRESHOLD = 10 // Number of recent samples for thresholding
    private let THRESHOLD_SCALING_FACTOR: Float = 1.5 // Adjust sensitivity
    private var isCalibrated = false  // Prevents early step detection
    private var accelHistory: [Double] = []  // Stores acceleration values for dynamic thresholding

    @Published var rawAccelerationData: [AccelFFTRecord] = []
    @Published var filteredAccelerationData: [AccelFFTRecord] = []
    @Published var detectedSteps: [AccelFFTRecord] = []
    @Published var stepCount: Int = 0
    @Published var avgStepLength: Double = 0.0
    @Published var stepVariance: Double = 0.0
    @Published var accuracy: Double = 0.0  // Accuracy compared to TARGET_STEP_LENGTH
    @Published var recommendation: String = "Start Walking to See Analysis"
    
    private var cumulativeVelocity: SIMD3<Float> = SIMD3<Float>(0, 0, 0)
    private var cumulativePosition: SIMD3<Float> = SIMD3<Float>(0, 0, 0)
    private var lastTimestamp: TimeInterval?
    
    private var velIntegral = Integral()
    private var posIntegral = Integral()
    private var dt = DeltaTime()

    private var collectedData: [AccelFFTRecord] = []
    private var fftSetup: vDSP_DFT_Setup?
    
    // Step detection states
    private var positiveSparkDetected: Bool = false
    private var stepStartTime: Float?
    private var lastPositiveSparkTime: Float?
    private var lastNegativeSparkTime: Float?

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
            timestamp: Float(timestamp),
            accelX: Double(ag.x),
            accelY: Double(ag.y),
            accelZ: Double(ag.z),
            accelMagnitude: Double(accelMagnitude),
            gyroX: Double(gyro.x),
            gyroY: Double(gyro.y),
            gyroZ: Double(gyro.z),
            filteredAccelMagnitude: nil,
            stepDetected: false,
            stepLength: nil
        )

        collectedData.append(record)
        DispatchQueue.main.async {
            self.rawAccelerationData.append(record)
        }
        // **Start step detection only after calibration phase**
        if collectedData.count >= WINDOW_SIZE_THRESHOLD {
            isCalibrated = true
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

        var filteredData = data // Copy to store filtered values
        let stepSize = WINDOW_SIZE / 2  // 50% overlapping window

        for i in stride(from: 0, to: data.count - WINDOW_SIZE, by: stepSize) {
            // Extract windowed segment
            var realParts = Array(data[i..<i + WINDOW_SIZE])
            var imaginaryParts = [Float](repeating: 0.0, count: WINDOW_SIZE)

            var realOutput = realParts
            var imaginaryOutput = imaginaryParts

            // Compute FFT (Use separate input/output buffers)
            vDSP_DFT_Execute(fftSetup, realParts, imaginaryParts, &realOutput, &imaginaryOutput)

            // Compute frequency bins
            let frequencies = (0..<WINDOW_SIZE).map { Float($0) * SAMPLING_RATE / Float(WINDOW_SIZE) }

            // Apply low-pass filter by zeroing out high frequencies
            for j in 0..<WINDOW_SIZE {
                if frequencies[j] > CUTOFF_FREQUENCY {
                    realOutput[j] = 0.0
                    imaginaryOutput[j] = 0.0
                }
            }

            // Inverse FFT (Again, use separate buffers)
            vDSP_DFT_Execute(fftSetup, realOutput, imaginaryOutput, &realParts, &imaginaryParts)

            // Apply inverse scaling to match Python output
            let scaleFactor = 1.0 / Float(WINDOW_SIZE)
            for j in 0..<WINDOW_SIZE {
                filteredData[i + j] = realParts[j] * scaleFactor
            }
        }

        return filteredData
    }

    private func detectSteps() {
        var lastStepTime: Float? = nil
        let POSITIVE_SPARK_LOWER: Double = 9.0
        let POSITIVE_SPARK_UPPER: Double = 14.0
        let NEGATIVE_SPARK_LOWER: Double = 13.0
        let NEGATIVE_SPARK_UPPER: Double = 15.0
        let MAX_TIME_BETWEEN_STEPS: Float = 5.0  // Reset if no step detected for too long
        let MIN_STEP_LENGTH: Double = 5.0  // Ignore step lengths smaller than 5 inches

        for i in 1..<collectedData.count {
            let accelMag = collectedData[i].filteredAccelMagnitude ?? collectedData[i].accelMagnitude

            // **Positive Spark Detection (Step Start) - Range between 8 and 15**
            if accelMag > POSITIVE_SPARK_LOWER, accelMag < POSITIVE_SPARK_UPPER, !positiveSparkDetected, lastNegativeSparkTime != nil || stepStartTime == nil {
                positiveSparkDetected = true
                stepStartTime = Float(collectedData[i].timestamp)
                lastPositiveSparkTime = stepStartTime

                // **DO NOT reset cumulative velocity/position immediately**
                velIntegral.reset(vec: SIMD3<Float>(0, 0, 0))
                posIntegral.reset(vec: SIMD3<Float>(0, 0, 0))
            }

            // **Negative Spark Detection (Step End)**
            else if positiveSparkDetected, accelMag > NEGATIVE_SPARK_LOWER, accelMag < NEGATIVE_SPARK_UPPER {
                positiveSparkDetected = false
                lastNegativeSparkTime = Float(collectedData[i].timestamp)

                if let startTime = stepStartTime {
                    let deltaTime = Float(collectedData[i].timestamp - startTime)

                    if MIN_DELTA_TIME <= deltaTime && deltaTime <= MAX_DELTA_TIME {
                        let accelVec = SIMD3<Float>(
                            Float(collectedData[i].accelX),
                            Float(collectedData[i].accelY),
                            Float(collectedData[i].accelZ)
                        )

                        cumulativeVelocity = velIntegral.step(v: accelVec, dt: deltaTime)

                        // **Handle case where next step is too soon or step detection stalls**
                        if let lastTime = lastStepTime {
                            let timeSinceLastStep = collectedData[i].timestamp - lastTime
                            if timeSinceLastStep > MAX_TIME_BETWEEN_STEPS {
                                print("⏳ Resetting due to long delay (\(timeSinceLastStep)s)")
                                cumulativeVelocity = SIMD3<Float>(0, 0, 0)
                                cumulativePosition = SIMD3<Float>(0, 0, 0)
                            }
                        }

                        cumulativePosition = posIntegral.step(v: cumulativeVelocity, dt: deltaTime)

                        // **Bias Compensation**
                        let biasCorrectionFactor: Float = 0.98
                        cumulativePosition *= biasCorrectionFactor

                        let stepLength = Double(length(cumulativePosition))

                        if stepLength >= MIN_STEP_LENGTH {
                            collectedData[i].stepDetected = true
                            collectedData[i].stepLength = stepLength
                            collectedData[i].positiveSparkTime = lastPositiveSparkTime
                            collectedData[i].negativeSparkTime = lastNegativeSparkTime

                            lastStepTime = collectedData[i].timestamp
                        }
                    }
                    stepStartTime = nil
                }

                // **Reset after the step is processed**
                cumulativeVelocity = SIMD3<Float>(0, 0, 0)
                cumulativePosition = SIMD3<Float>(0, 0, 0)
            }

            // **Handle case where filtered acceleration never reaches negative spark threshold**
            else if positiveSparkDetected, accelMag > POSITIVE_SPARK_LOWER, accelMag < POSITIVE_SPARK_UPPER {
                let timeSinceStart = Float(collectedData[i].timestamp) - (stepStartTime ?? 0)
                if timeSinceStart > MAX_DELTA_TIME {
                    positiveSparkDetected = false
                    stepStartTime = nil
                }
            }
        }

        // **Call computeStatistics() after step detection**
        computeStatistics()
    }

    
    func exportGaitData(fileName: String) -> URL? {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        var csvText = "Timestamp,AccelX,AccelY,AccelZ,AccelMagnitude,FilteredAccelMag,GyroX,GyroY,GyroZ,StepDetected,StepLength,PositiveSparkTime,NegativeSparkTime\n"

        for record in collectedData {
            csvText.append("\(record.timestamp),\(record.accelX),\(record.accelY),\(record.accelZ),\(record.accelMagnitude),\(String(describing: record.filteredAccelMagnitude)),\(record.gyroX),\(record.gyroY),\(record.gyroZ),\(record.stepDetected ? "Yes" : "No"),\(record.stepLength != nil ? String(record.stepLength!) : ""),\(record.positiveSparkTime != nil ? String(record.positiveSparkTime!) : ""),\(record.negativeSparkTime != nil ? String(record.negativeSparkTime!) : "")\n")
        }

        do {
            try csvText.write(to: path, atomically: true, encoding: .utf8)
            return path
        } catch {
            print("Failed to write CSV: \(error.localizedDescription)")
            return nil
        }
    }

    private func computeStatistics() {
        let validSteps = collectedData.filter { $0.stepDetected && ($0.stepLength ?? 0) >= 5.0 }
        
        guard !validSteps.isEmpty else {
            recommendation = "No valid steps detected."
            print("❌ No valid steps detected.")
            return
        }

        let stepLengths = validSteps.map { $0.stepLength ?? 0 }
        avgStepLength = stepLengths.reduce(0, +) / Double(stepLengths.count)
        stepVariance = stepLengths.map { pow($0 - avgStepLength, 2) }.reduce(0, +) / Double(stepLengths.count)
        accuracy = (1 - abs(avgStepLength - TARGET_STEP_LENGTH) / TARGET_STEP_LENGTH) * 100.0

        recommendation = accuracy >= 90.0 ? "Great! Keep your step length." : (avgStepLength > TARGET_STEP_LENGTH ? "Shorten your steps" : "Increase your steps")

        print("=== Gait Analysis Statistics ===")
//        print("Total Valid Steps: \(validSteps.count)")
        print("Avg Step Length: \(String(format: "%.2f", avgStepLength)) inches")
        print("Step Variance: \(String(format: "%.2f", stepVariance)) inches²")
        print("Accuracy: \(String(format: "%.1f", accuracy))%")
        print("Recommendation: \(recommendation)")
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
    let timestamp: Float
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
    var positiveSparkTime: Float?
    var negativeSparkTime: Float?
}
