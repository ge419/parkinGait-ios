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

/// A view for tracking step length using the `StepLengthCalculator`.
struct StepLengthCalculatorView: View {
    @State private var isWalking = false
    @State private var stepLength: Double = 0
    @State private var recentAccelData: [Double] = []
    @State private var gaitData: [GaitData] = []
    
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
            
            if !recentAccelData.isEmpty {
                Chart {
                    ForEach(recentAccelData.indices, id: \.self) { index in
                        LineMark(
                            x: .value("Index", index),
                            y: .value("Z-Axis Acceleration", recentAccelData[index])
                        )
                    }
                }
                .frame(height: 300)
                .padding()
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
                    
                    // Calculate step length
                    if let detectedStepLength = stepLengthCalculator.processMotionData(
                        accel: accel,
                        gyro: gyro,
                        quaternion: quaternion,
                        timestamp: timestamp
                    ) {
                        stepLength = detectedStepLength
                        recentAccelData.append(Double(accel.z))
                        
                        // stores most recent 50 acceleration values
                        if recentAccelData.count > 50 {
                            recentAccelData.removeFirst()
                        }
                    }
                }
            }
        }
    }
    
    private func stopIMU() {
        motionManager.stopDeviceMotionUpdates()
        recentAccelData.removeAll()
    }
    
    private func exportGaitData() {
        if let fileURL = exportToCSV(data: gaitData, fileName: "data.csv") {
            let activityView = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootViewController = windowScene.windows.first?.rootViewController {
                rootViewController.present(activityView, animated: true, completion: nil)
            }
        }
    }
}

#Preview {
    StepLengthCalculatorView()
}
