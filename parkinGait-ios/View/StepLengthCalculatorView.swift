//
//  StepLengthCalculatorView.swift
//  parkinGait-ios
//
//  Created by 신창민 on 11/19/24.
//


import SwiftUI
import CoreMotion
import simd
import Charts

/// A view for tracking and displaying step length using the `StepLengthCalculator`.
struct StepLengthCalculatorView: View {
    @State private var isWalking = false
    @State private var stepLength: Double = 0
    @State private var recentAccelData = RingBuffer<Double>(size: 50)
    
    private var motionManager = CMMotionManager()
    private var stepLengthCalculator = StepLengthCalculator()
    
    var body: some View {
        VStack {
            Text("Step Length Calculator")
                .font(.largeTitle)
                .padding(.top, 20)
            
            Text("Step Length: \(String(format: "%.2f", stepLength)) inches")
                .font(.title2)
                .padding(.top, 10)
            
            Button(action: toggleIMU) {
                Text(isWalking ? "Stop Tracking" : "Start Tracking")
                    .font(.title2)
                    .padding()
                    .background(isWalking ? Color.red : Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            
            if !recentAccelData.elements().isEmpty {
                Chart {
                    ForEach(recentAccelData.elements().indices, id: \.self) { index in
                        LineMark(
                            x: .value("Index", index),
                            y: .value("Z-Axis Acceleration", recentAccelData.elements()[index])
                        )
                    }
                }
                .frame(height: 300)
                .padding()
                .chartXAxisLabel("Time Index")
                .chartYAxisLabel("Z-Axis Acceleration")
            }
            
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
        .navigationTitle("Step Length Calculator")
        .onDisappear {
            stopIMU()
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
                    // Prepare inputs for StepLengthCalculator
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
                    
                    if self.recentAccelData.elements().isEmpty {
                        self.stepLengthCalculator.startMotionTracking(timestamp: timestamp)
                    }
                    
                    // Update chart data
                    recentAccelData.append(Double(accel.z))
                    
                    // Process motion data to calculate step length
                    if let detectedStepLength = stepLengthCalculator.processMotionData(
                        accel: accel,
                        gyro: gyro,
                        quaternion: quaternion,
                        timestamp: timestamp
                    ) {
                        // Update step length on the UI
                        DispatchQueue.main.async {
                            stepLength = detectedStepLength
                        }
                    }
                } else if let error = error {
                    print("Device motion error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func stopIMU() {
        motionManager.stopDeviceMotionUpdates()
        recentAccelData = RingBuffer(size: 50)
    }
    
    private func exportGaitData() {
        if let fileURL = stepLengthCalculator.exportGaitData(fileName: "gait_data.csv") {
            let activityView = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootViewController = windowScene.windows.first?.rootViewController {
                rootViewController.present(activityView, animated: true, completion: nil)
            }
        } else {
            print("No gait data to export.")
        }
    }
}

#Preview {
    StepLengthCalculatorView()
}
