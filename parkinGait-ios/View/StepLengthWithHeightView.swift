//
//  StepLengthWithHeightView.swift
//  parkinGait-ios
//
//  Created by 신창민 on 11/19/24.
//

import SwiftUI
import CoreMotion
import Charts

struct StepLengthWithHeightView: View {
    @State private var isWalking = false
    @State private var stepLength: Double = 0
    @State private var recentAccelData: [Double] = []
    @State private var gaitData: [GaitData] = []
    
    private let userHeight: Double = 1.75  // Example height in meters
    private var motionManager = CMMotionManager()
    private var stepLengthWithHeight = StepLengthWithHeight()
    
    var body: some View {
        VStack {
            Text("Step Length with Height")
                .font(.largeTitle)
                .padding(.top, 20)
            
            Text("Step Length: \(String(format: "%.2f", stepLength)) inches")
                .font(.title)
                .padding(.top, 10)
            
            Button(action: toggleIMU) {
                Text(isWalking ? "Stop Tracking" : "Start Tracking")
                    .font(.title2)
                    .padding()
                    .background(isWalking ? Color.red : Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.top, 20)
            
            if !recentAccelData.isEmpty {
                Chart {
                    ForEach(recentAccelData.indices, id: \.self) { index in
                        LineMark(
                            x: .value("Index", index),
                            y: .value("Acceleration Magnitude", recentAccelData[index])
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
        .navigationTitle("Step Length with Height")
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
                    let accelMagnitude = sqrt(pow(motionData.userAcceleration.x, 2) +
                                              pow(motionData.userAcceleration.y, 2) +
                                              pow(motionData.userAcceleration.z, 2))
                    
                    // Record step if peak detected (simplified example, you may replace this with more complex logic)
                    if accelMagnitude > 1.5 {  // Example threshold
                        self.stepLengthWithHeight.recordStep(timestamp: Date().timeIntervalSince1970)
                    }
                    
                    // Calculate step length using height
                    let calculatedStepLength = self.stepLengthWithHeight.calculateStepLength(
                        accelMagnitude: accelMagnitude,
                        height: self.userHeight
                    )
                    
                    // Update the UI
                    self.stepLength = calculatedStepLength
                    self.recentAccelData.append(accelMagnitude)
                    
                    // Save data for export
                    let gaitEntry = GaitData(
                        timestamp: Date().timeIntervalSince1970,
                        accelX: motionData.userAcceleration.x,
                        accelY: motionData.userAcceleration.y,
                        accelZ: motionData.userAcceleration.z,
                        gyroX: motionData.rotationRate.x,
                        gyroY: motionData.rotationRate.y,
                        gyroZ: motionData.rotationRate.z,
                        stepLength: calculatedStepLength
                    )
                    self.gaitData.append(gaitEntry)
                    
                    if self.recentAccelData.count > 50 {
                        self.recentAccelData.removeFirst()
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
    StepLengthWithHeightView()
}
