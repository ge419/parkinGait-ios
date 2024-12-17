import SwiftUI
import CoreMotion
import simd
import Charts

struct AccelMagView: View {
    @State private var isWalking = false
    @State private var stepLength: Double = 0
    @State private var recentAccelData = RingBuffer<Double>(size: 50)
    @State private var stepLengths: [Double] = []  // List of step lengths

    private var motionManager = CMMotionManager()
    private var accelMag = AccelMag()
    
    var body: some View {
        VStack {
            Text("Current Step Length: \(String(format: "%.2f", stepLength)) inches")
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
            
            // Real-time chart display
            if !recentAccelData.elements().isEmpty {
                Chart {
                    ForEach(recentAccelData.elements().indices, id: \.self) { index in
                        LineMark(
                            x: .value("Index", index),
                            y: .value("Acceleration Magnitude", recentAccelData.elements()[index])
                        )
                    }
                }
                .frame(height: 200)
                .padding()
                .chartXAxisLabel("Time Index")
                .chartYAxisLabel("Acceleration Magnitude (m/s²)")
            }
            
            // Real-time Step Length List
            Text("Step Lengths:")
                .font(.title2)
                .padding(.top, 10)
            
            List {
                ForEach(stepLengths.indices, id: \.self) { index in
                    Text("Step \(index + 1): \(String(format: "%.2f", stepLengths[index])) inches")
                }
            }
            .frame(height: 200)  // Limit height of list
            
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
        .navigationTitle("Acceleration Magnitude Version")
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
                    
                    if self.recentAccelData.elements().isEmpty {
                        self.accelMag.startMotionTracking(timestamp: timestamp)
                    }
                    
                    // Calculate acceleration magnitude
                    let accelMagnitude = Double(sqrt(accel.x * accel.x + accel.y * accel.y + accel.z * accel.z))
                    recentAccelData.append(accelMagnitude)
                    
                    // Process motion data to calculate step length
                    if let detectedStepLength = accelMag.processAcceleration(
                        accel: accel,
                        gyro: gyro,
                        quaternion: quaternion,
                        timestamp: timestamp
                    ) {
                        DispatchQueue.main.async {
                            stepLength = detectedStepLength
                            stepLengths.append(detectedStepLength)  // Append detected step length
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
        accelMag.resetAllIntegrations()  // Reset velocity and position integrators
        print("Tracking stopped, integrators reset.")
    }

    
    private func exportGaitData() {
        if let fileURL = accelMag.exportGaitData(fileName: "gait_data.csv") {
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
