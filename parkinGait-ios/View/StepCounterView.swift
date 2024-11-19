//
//  StepCounterView.swift
//  parkinGait-ios
//
//  Created by 신창민 on 11/19/24.
//


import SwiftUI
import CoreMotion
import Charts

/// A view for tracking steps and distance using the `StepCounter`.
struct StepCounterView: View {
    @State private var isWalking = false
    @State private var stepCount: Int = 0
    @State private var totalDistance: Double = 0.0  // Total distance in meters
    @State private var recentAccelData: [Double] = []
    @State private var gaitData: [GaitData] = []
    
    private var stepCounter = StepCounter()  // Instance of the StepCounter model
    
    var body: some View {
        VStack {
            Text("Step Counter")
                .font(.largeTitle)
                .padding(.top, 20)
            
            Text("Steps: \(stepCount)")
                .font(.title)
                .padding(.top, 10)
            
            Text("Total Distance: \(String(format: "%.2f", totalDistance)) meters")
                .font(.title2)
                .padding(.top, 10)
            
            Button(action: toggleStepCounting) {
                Text(isWalking ? "Stop Counting" : "Start Counting")
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
        .navigationTitle("Step Counter")
        .onDisappear {
            stopStepCounting()
        }
    }
    
    /// Toggles the step counting process.
    private func toggleStepCounting() {
        isWalking.toggle()
        if isWalking {
            startStepCounting()
        } else {
            stopStepCounting()
        }
    }
    
    /// Starts the step counting process using the `StepCounter` model.
    private func startStepCounting() {
        stepCounter.startStepCounting()
        stepCounter.onStepDetected = { stepLength, steps, distance, accelMagnitude in
            stepCount = steps
            totalDistance = distance
            recentAccelData.append(accelMagnitude)
            
            if recentAccelData.count > 50 {
                recentAccelData.removeFirst()
            }
        }
    }
    
    /// Stops the step counting process and clears the state.
    private func stopStepCounting() {
        stepCounter.stopStepCounting()
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
    StepCounterView()
}
