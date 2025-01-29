//
//  AccelMagFFT.swift
//  parkinGait-ios
//
//  Created by 신창민 on 01/28/25.
//

import Foundation
import Accelerate
import simd

class AccelMagFFT: ObservableObject {
    private let METERS_TO_INCHES: Float = 39.3701
    private let CUTOFF_FREQUENCY: Float = 0.5  // Hz
    private let SAMPLING_RATE: Float = 10.0  // Hz
    private let WINDOW_SIZE = 256
    private let ACCEL_THRESHOLD: Float = 10.0  // Threshold for step detection
    private let MIN_DELTA_TIME: TimeInterval = 0.5
    private let MAX_DELTA_TIME: TimeInterval = 2.0
    private let TARGET_STEP_LENGTH: Double = 30.0  // Target step length in inches

    @Published var filteredData: [(timestamp: TimeInterval, accelMagnitude: Float)] = []
    @Published var detectedSteps: [(timestamp: TimeInterval, stepLength: Double)] = []
    @Published var avgStepLength: Double = 0.0
    @Published var stepVariance: Double = 0.0
    @Published var recommendation: String = "Start Walking to See Analysis"

    private var collectedData: [(timestamp: TimeInterval, accelMagnitude: Float)] = []
    
    func collectData(timestamp: TimeInterval, accel: SIMD3<Float>, quaternion: simd_quatf) {
        let gravity = getGravity(q: quaternion)
        let ag = projectAccelOnGravity(accel: accel, gravity: gravity) * METERS_TO_INCHES
        let accelMagnitude = length(ag)
        
        collectedData.append((timestamp, accelMagnitude))
    }

    func analyzeSteps() {
        guard collectedData.count >= WINDOW_SIZE else {
            recommendation = "Not enough data to analyze."
            return
        }

        // Apply FFT Noise Filtering
        let timestamps = collectedData.map { $0.timestamp }
        var accelMagnitudes = collectedData.map { $0.accelMagnitude }
        let filteredMagnitudes = applyFFTFilter(&accelMagnitudes)

        DispatchQueue.main.async {
            self.filteredData = zip(timestamps, filteredMagnitudes).map { ($0, $1) }
            self.detectSteps(timestamps: timestamps, filteredMagnitudes: filteredMagnitudes)
            self.calculateStepStatistics()
        }
    }

    private func applyFFTFilter(_ data: inout [Float]) -> [Float] {
        guard data.count >= WINDOW_SIZE else { return data }

        var realParts = data
        var imaginaryParts = [Float](repeating: 0.0, count: data.count)

        let fftSetup = vDSP_DFT_zop_CreateSetup(nil, vDSP_Length(WINDOW_SIZE), vDSP_DFT_Direction.FORWARD)

        realParts.withUnsafeMutableBufferPointer { realPointer in
            imaginaryParts.withUnsafeMutableBufferPointer { imagPointer in
                vDSP_DFT_Execute(fftSetup!, realPointer.baseAddress!, imagPointer.baseAddress!, realPointer.baseAddress!, imagPointer.baseAddress!)
            }
        }

        // Filter high frequencies
        let frequencies = (0..<data.count).map { Float($0) * SAMPLING_RATE / Float(data.count) }
        for i in 0..<data.count {
            if frequencies[i] > CUTOFF_FREQUENCY {
                realParts[i] = 0.0
                imaginaryParts[i] = 0.0
            }
        }

        // Perform inverse FFT
        vDSP_DFT_Execute(fftSetup!, realParts, imaginaryParts, &realParts, &imaginaryParts)

        return realParts
    }

    private func detectSteps(timestamps: [TimeInterval], filteredMagnitudes: [Float]) {
        var stepStartTime: TimeInterval?
        var detectedStepsTemp: [(timestamp: TimeInterval, stepLength: Double)] = []

        for i in 1..<filteredMagnitudes.count {
            let accelMag = filteredMagnitudes[i]

            if accelMag > ACCEL_THRESHOLD, stepStartTime == nil {
                stepStartTime = timestamps[i]
            } else if accelMag < ACCEL_THRESHOLD, let startTime = stepStartTime {
                let deltaTime = timestamps[i] - startTime

                if MIN_DELTA_TIME <= deltaTime && deltaTime <= MAX_DELTA_TIME {
                    let stepLength = Double(abs(accelMag - filteredMagnitudes[i - 1]))  // Approximate step length
                    detectedStepsTemp.append((timestamps[i], stepLength))
                }
                stepStartTime = nil
            }
        }

        detectedSteps = detectedStepsTemp
    }

    private func calculateStepStatistics() {
        guard !detectedSteps.isEmpty else {
            recommendation = "No steps detected."
            return
        }

        let stepLengths = detectedSteps.map { $0.stepLength }
        avgStepLength = stepLengths.reduce(0, +) / Double(stepLengths.count)
        stepVariance = stepLengths.map { pow($0 - avgStepLength, 2) }.reduce(0, +) / Double(stepLengths.count)

        let differenceFromTarget = avgStepLength - TARGET_STEP_LENGTH
        recommendation = differenceFromTarget > 0 ? "Shorten your steps" : "Increase your steps"
    }
    
    private func getGravity(q: simd_quatf) -> SIMD3<Float> {
        return SIMD3<Float>(2 * (q.vector.w * q.vector.z - q.vector.x * q.vector.y),
                            2 * (q.vector.y * q.vector.z + q.vector.w * q.vector.x),
                            q.vector.w * q.vector.w - q.vector.x * q.vector.x - q.vector.y * q.vector.y + q.vector.z * q.vector.z)
    }

    private func projectAccelOnGravity(accel: SIMD3<Float>, gravity: SIMD3<Float>) -> SIMD3<Float> {
        return accel - dot(accel, gravity) * gravity
    }
}
