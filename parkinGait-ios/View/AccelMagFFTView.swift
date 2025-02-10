//
//  AccelMagFFTView.swift
//  parkinGait-ios
//
//  Created by 신창민 on 1/28/25.
//

import SwiftUI
import CoreMotion
import Charts
import simd

struct AccelMagFFTView: View {
    private var accelMagFFT = AccelMagFFT()
    @State private var isWalking = false
    private var motionManager = CMMotionManager()

    var body: some View {
        VStack {
            // **Step Statistics**
            VStack(alignment: .leading, spacing: 5) {
                Text("Gait Analysis Summary")
                    .font(.headline)
                    .foregroundColor(.blue)
                    .padding(.top)

                Text("Total Steps: \(accelMagFFT.stepCount)")
                Text("Avg Step Length: \(String(format: "%.2f", accelMagFFT.avgStepLength)) inches")
                Text("Step Variance: \(String(format: "%.2f", accelMagFFT.stepVariance)) inches²")
                Text("Accuracy: \(String(format: "%.1f", accelMagFFT.accuracy))%")
                Text(accelMagFFT.recommendation)
                    .foregroundColor(.red)
            }
            .padding()

            // **Start/Stop Tracking Button**
            Button(action: toggleIMU) {
                Text(isWalking ? "Stop Tracking" : "Start Tracking")
                    .font(.title2)
                    .padding()
                    .background(isWalking ? Color.red : Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding()

            // **Filtered Acceleration Graph with Step Lengths**
            if !accelMagFFT.filteredAccelerationData.isEmpty {
                Chart {
                    // **Plot Filtered Acceleration**
                    ForEach(accelMagFFT.filteredAccelerationData.indices, id: \.self) { index in
                        LineMark(
                            x: .value("Time", accelMagFFT.filteredAccelerationData[index].timestamp),
                            y: .value("Filtered Acceleration", accelMagFFT.filteredAccelerationData[index].accelMagnitude)
                        )
                    }

                    // **Plot Detected Steps**
                    ForEach(accelMagFFT.detectedSteps, id: \.timestamp) { step in
                        PointMark(
                            x: .value("Time", step.timestamp),
                            y: .value("Filtered Acceleration", step.accelMagnitude)
                        )
                        .foregroundStyle(.red)
                        .annotation(position: .top) {
                            Text("\(String(format: "%.1f", step.stepLength ?? 0))\"")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }
                .frame(height: 250)
                .padding()
            }

            // **Export Data Button**
            Button(action: exportGaitData) {
                Text("Export Data")
                    .font(.title2)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.top, 20)
        }
    }

    private func toggleIMU() {
        isWalking.toggle()

        if isWalking {
            startIMU()
        } else {
            stopIMU()
        }
    }

    private func startIMU() {
        if motionManager.isDeviceMotionAvailable {
            motionManager.deviceMotionUpdateInterval = 0.1
            motionManager.startDeviceMotionUpdates(to: .main) { data, error in
                if let motionData = data {
                    let accel = SIMD3<Float>(
                        Float(motionData.userAcceleration.x),
                        Float(motionData.userAcceleration.y),
                        Float(motionData.userAcceleration.z)
                    )
                    let gyro = SIMD3<Float>(
                        Float(motionData.rotationRate.x),
                        Float(motionData.rotationRate.y),
                        Float(motionData.rotationRate.z)
                    )
                    let quaternion = motionData.attitude.quaternion
                    let timestamp = motionData.timestamp

                    accelMagFFT.collectData(timestamp: timestamp, accel: accel, gyro: gyro, quaternion: quaternion)
                } else if let error = error {
                    print("Device motion error: \(error.localizedDescription)")
                }
            }
        }
    }

    private func exportGaitData() {
        if let fileURL = accelMagFFT.exportGaitData(fileName: "gait_data.csv") {
            let activityView = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootViewController = windowScene.windows.first?.rootViewController {
                rootViewController.present(activityView, animated: true, completion: nil)
            }
        } else {
            print("No gait data to export.")
        }
    }

    private func stopIMU() {
        motionManager.stopDeviceMotionUpdates()
        accelMagFFT.analyzeSteps() // Automatically analyze after stopping
        
        DispatchQueue.main.async {
            self.isWalking = false
            self.accelMagFFT.stepCount = self.accelMagFFT.detectedSteps.count
            self.accelMagFFT.avgStepLength = self.accelMagFFT.avgStepLength
            self.accelMagFFT.stepVariance = self.accelMagFFT.stepVariance
            self.accelMagFFT.accuracy = self.accelMagFFT.accuracy
            self.accelMagFFT.recommendation = self.accelMagFFT.recommendation
        }
    }
}

#Preview {
    AccelMagFFTView()
}
