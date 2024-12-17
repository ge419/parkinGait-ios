//
//  DynamicStepLengthCounterView.swift
//  parkinGait-ios
//
//  Created by 신창민 on 12/17/24.
//

import SwiftUI
import CoreMotion
import AVFoundation
import simd

struct DynamicStepLengthCounterView: View {
    @EnvironmentObject var viewModel: AuthViewModel
    
    @State private var gaitConstant: Double = 0
    @State private var threshold: Double = 0
    @State private var goalStep: Double = 0
    @State private var placement: String = ""
    
    @State private var isWalking = false
    @State private var stepLength: Double = 0
    @State private var range: Double = 30
    @State private var vibrateOption = "Over Step Goal"
    @State private var vibrateValue = "Vibrate Phone"
    @State private var isPlaying = false
    @State private var player: AVAudioPlayer?
    @State private var timer: Timer?
    
    @State private var accelerometerData: [CMAcceleration] = []
    @State private var stepLengthFirebase: [Double] = []
    @State private var peakTimes: [Double] = []
    @State private var waitingFor1stValue = false
    @State private var waitingFor2ndValue = false
    @State private var waitingFor3rdValue = false
    @State private var isEnabled = false
    @State private var lastPeakSign = -1
    @State private var lastPeakIndex = 0
    @State private var isFirstPeakPositive = false
    @State private var dynamicThreshold: Double = 0
    @State private var recentAccelData: [Double] = []
    @State private var previousFilteredValue: Double = 0.0
    
    private var velIntegral = Integral()
    private var posIntegral = Integral()
    
    
    private var motionManager = CMMotionManager()
    
    let ACCELEROMETER_TIMING = 0.1
    let ACCELEROMETER_HZ = 1.0 / 0.1
    let USER_HEIGHT = 1.778
    private let METERS_TO_INCHES: Double = 39.3701
    let DISTANCE_THRESHOLD = 3.0
    let MIN_PEAK_INTERVAL = 0.5
    
    let bgColor = Color(red: 0.8706, green: 0.8549, blue: 0.8235)
    
    var body: some View {
        NavigationStack {
            ScrollView{
                VStack {
                    Text("Dynamic Threshold Step Detection")
                        .font(.largeTitle)
                        .padding(.top, 20)
                    
                    Button(action: toggleIMU) {
                        Text(isWalking ? "Stop Walking" : "Start Walking")
                            .font(.title)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(5)
                    }
                    Text("Step Length Estimate: \(String(format: "%.2f", stepLength)) inches")
                        .font(.title2)
                        .padding(.top, 20)
                    Text("Goal Step Length: \(String(format: "%.0f", goalStep)) inches")
                        .foregroundColor(.gray)
                        .font(.body)
                        .padding(.top, 5)
                    Text("Threshold: \(String(format: "%.0f", threshold)) inches")
                        .foregroundColor(.gray)
                        .font(.body)
                        .padding(.top, 5)
                    Text("Gait Constant: \(String(format: "%.0f", gaitConstant)) inches")
                        .foregroundColor(.gray)
                        .font(.body)
                        .padding(.top, 5)

                }
                .onAppear{
                    if let calibration = viewModel.currentCalibration {
                        gaitConstant = calibration.gaitConstant
                        threshold = calibration.threshold
                        goalStep = Double(calibration.goalStep) ?? 0
                        placement = calibration.placement
                    }
                }
            }
            .navigationTitle("Dynamic Step Length Calculator")
            .navigationBarTitleDisplayMode(.inline)
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

    private func stopIMU() {
        motionManager.stopDeviceMotionUpdates()
        print("Stopped IMU updates")
    }

    private func startIMU() {
        print("Starting walking...")
        accelerometerData.removeAll()
        peakTimes.removeAll()
        stepLength = 0
        waitingFor1stValue = false
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            print("Walking setup complete.")
            isWalking = true
            waitingFor1stValue = true
            waitingFor2ndValue = false
            waitingFor3rdValue = false
            isFirstPeakPositive = false
            lastPeakSign = -1
            lastPeakIndex = -1
            
            if motionManager.isDeviceMotionAvailable {
                print("Accelerometer available. Starting updates.")
                motionManager.deviceMotionUpdateInterval = ACCELEROMETER_TIMING
                motionManager.startDeviceMotionUpdates(to: .main) {data, error in
                    if let data = data {
                        handleNewAccelerometerData(data: data)
                    }
                }
            } else {
                print("Accelerometer not available.")
            }
        }
    }

    func handleToggleWalking() {
        if isWalking {
            print("Stopping walking...")
            isWalking = false
            motionManager.stopAccelerometerUpdates()
        } else {
            print("Starting walking...")
            accelerometerData.removeAll()
            peakTimes.removeAll()
            stepLength = 0
            waitingFor1stValue = false
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                print("Walking setup complete.")
                isWalking = true
                waitingFor1stValue = true
                waitingFor2ndValue = false
                waitingFor3rdValue = false
                isFirstPeakPositive = false
                lastPeakSign = -1
                lastPeakIndex = -1
                
                if motionManager.isDeviceMotionAvailable {
                    print("Accelerometer available. Starting updates.")
                    motionManager.deviceMotionUpdateInterval = ACCELEROMETER_TIMING
                    motionManager.startDeviceMotionUpdates(to: .main) {data, error in
                        if let data = data {
                            handleNewAccelerometerData(data: data)
                        }
                    }
                } else {
                    print("Accelerometer not available.")
                }
            }
        }
    }

    func handleNewAccelerometerData(data: CMDeviceMotion) {
        // Apply low-pass filter to raw acceleration data
        let alpha: Double = 0.1 // Smoothing factor, lower values mean smoother
        let filteredZ = applyLowPassFilter(newValue: data.userAcceleration.z, alpha: alpha)
//        let filteredX = applyLowPassFilter(newValue: data.userAcceleration.y, alpha: alpha)

        // Append filtered acceleration data
        accelerometerData.append(data.userAcceleration)
        recentAccelData.append(filteredZ)
//        recentAccelData.append(filteredX)

        if recentAccelData.count > 20 {
            recentAccelData.removeFirst()
        }

        // Use filtered acceleration data for calculations
        let mean = recentAccelData.reduce(0, +) / Double(recentAccelData.count)
        let stdDev = self.stdDev(arr: recentAccelData)

        // Adjust the threshold formula to reduce sensitivity
        dynamicThreshold = mean + stdDev * 1.5
//        print("Dynamic Threshold (Filtered): \(dynamicThreshold)")

        let accel = SIMD3<Float>(
            Float(data.userAcceleration.x),
            Float(data.userAcceleration.y),
            Float(data.userAcceleration.z)
        )
        let quaternion = data.attitude.quaternion

        // Pass the filtered acceleration data to the step detection logic
        detectSteps(accel: accel, quaternion: quaternion)
    }

    func detectSteps(accel: SIMD3<Float>, quaternion: CMQuaternion) {
        let zData = accelerometerData.map { $0.z }
        let xData = accelerometerData.map { $0.x }
//        let mean = zData.reduce(0, +) / Double(zData.count)
        let mean = xData.reduce(0, +) / Double(xData.count)
//        let variance = zData.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(zData.count)
        let variance = xData.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(xData.count)
        let stdDev = sqrt(variance)
        let dynamicThresholdZ = mean + stdDev * 0.5
//        print("Step Detection - Dynamic Threshold Z: \(dynamicThresholdZ)")

        let currentIndex = zData.count - 1
        if currentIndex < 2 {
            print("Not enough data points.")
            return
        }

//        let zDataCurr = zData[currentIndex]
//        let zDataPrev = zData[currentIndex - 1]
        let zDataCurr = xData[currentIndex]
        let zDataPrev = xData[currentIndex - 1]
        let DataTime = Double(currentIndex) / ACCELEROMETER_HZ

        if waitingFor1stValue && ((zDataCurr < threshold && zDataPrev > threshold) || (zDataCurr > threshold && zDataPrev < threshold)) {
            if lastPeakIndex == -1 || (DataTime - peakTimes.last!) > MIN_PEAK_INTERVAL || currentIndex - lastPeakIndex > Int(threshold) || currentIndex - lastPeakIndex > Int(dynamicThresholdZ){
                if lastPeakSign == -1 {
                    peakTimes.append(DataTime)
                    lastPeakIndex = currentIndex
                    lastPeakSign = 1
                    isFirstPeakPositive = true
                    waitingFor1stValue = false
                    waitingFor2ndValue = true
                    print("First peak detected at \(DataTime)")
                }
            }
        }

        if waitingFor2ndValue && ((zDataCurr < threshold && zDataPrev > threshold) || (zDataCurr > threshold && zDataPrev < threshold)) {
            if (DataTime - peakTimes.last!) > MIN_PEAK_INTERVAL || currentIndex - lastPeakIndex > Int(threshold) || currentIndex - lastPeakIndex > Int(dynamicThresholdZ) {
                if lastPeakSign == 1 {
                    peakTimes.append(DataTime)
                    lastPeakIndex = currentIndex
                    lastPeakSign = -1
                    waitingFor2ndValue = false
                    waitingFor1stValue = true
                    print("Second peak detected at \(DataTime)")
                }
            }
        }

        if peakTimes.count == 2 {
            let peak2 = peakTimes.last!
            let peak1 = peakTimes.first!
            let peakBetweenTime = peak2 - peak1
//            print("Peak Between Time: \(peakBetweenTime)")
            
            let gravity = getGravity(q: quaternion)
            let ag = projectAccelOnGravity(accel: accel, gravity: gravity) * Float(METERS_TO_INCHES)
            
            let deltaTime = peakBetweenTime
            let velocity = velIntegral.step(v: ag, dt: Float(deltaTime))
            let positionIncrement = posIntegral.step(v: velocity, dt: Float(deltaTime))
//            let stepLengthEst = Double(length(positionIncrement))
            
            // Reset the integrals to avoid accumulation
            resetVel()
            resetPos()
            let stepLengthEst = peakBetweenTime * gaitConstant * METERS_TO_INCHES
            stepLength = stepLengthEst
            
            print("Step Length Estimated: \(stepLengthEst) inches")

            // Prepare for the next step
            peakTimes = [peakTimes.last!]
            waitingFor1stValue = true
        }
    }


    func stdDev(arr: [Double]) -> Double {
        let avg = arr.reduce(0, +) / Double(arr.count)
        let sumOfSquares = arr.reduce(0) { $0 + ($1 - avg) * ($1 - avg) }
        return sqrt(sumOfSquares / Double(arr.count))
    }
    
    private func resetPos() {
        velIntegral.reset(vec: SIMD3<Float>(0, 0, 0))
        posIntegral.reset(vec: SIMD3<Float>(0, 0, 0))
//        dt.set(ts: 0)
    }
    
    private func resetVel() {
        velIntegral.reset(vec: SIMD3<Float>(0, 0, 0))
        posIntegral.resetPrev(vec: SIMD3<Float>(0, 0, 0))
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
    
//    func movingAverage(data: [Double], windowSize: Int) -> [Double] {
//        guard windowSize > 1, data.count >= windowSize else {
//            return data // Return original data if not enough points
//        }
//
//        var smoothed: [Double] = []
//        for i in 0...(data.count - windowSize) {
//            let window = data[i..<(i + windowSize)]
//            let average = window.reduce(0, +) / Double(windowSize)
//            smoothed.append(average)
//        }
//        return smoothed
//    }
    
    func movingAverage(data: [Double], windowSize: Int) -> [Double] {
        var result: [Double] = []
        
        for i in 0..<(data.count - windowSize + 1) {
            let currentWindow = Array(data[i..<(i + windowSize)])
            let windowAvg = currentWindow.reduce(0, +) / Double(windowSize)
            result.append(windowAvg)
        }
        
        return result
    }
    
    private func applyLowPassFilter(newValue: Double, alpha: Double) -> Double {
        let filteredValue = alpha * newValue + (1 - alpha) * previousFilteredValue
        previousFilteredValue = filteredValue
        return filteredValue
    }
}

#Preview {
    DynamicStepLengthCounterView()
}
