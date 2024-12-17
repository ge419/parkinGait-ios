//
//  Calibration.swift
//  parkinGait-ios
//
//  Created by 신창민 on 12/17/24.
//


import SwiftUI
import CoreMotion

struct Calibration: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject private var viewModel: AuthViewModel
    @State private var isCollecting = false
    @State private var accelerometerData: [CMAccelerometerData] = []
    @State private var goalStep: Double = 0
    @State private var newGoalStep: String = ""
    @State private var locationPlacement = "In Pocket/In Front"
    @State private var feedbackData: (steps: Int, strideLength: Double, gaitConstant: Double) = (0, 0, 0)
    @State private var showFeedback = false
    @FocusState private var isTextFieldFocused: Bool
    
    private let distanceTraveled: Double = 5
    private let distanceThreshold: Int = 3
    private let userHeight: Double = 1.778
    private let metersToInches: Double = 39.3701
    
    private var motionManager = CMMotionManager()
    
    private let locPlac = ["In Pocket/In Front", "In Waist/On Side"]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack {
                    Text("Calibration")
                        .font(.largeTitle)
                        .padding(.top, 20)
                    
                    Text("Recommended Step Length: \(goalStep, specifier: "%.0f") inches")
                        .font(.title2)
                        .padding(.top, 20)
                    
                    Text("This is our recommended goal step length. To personally modify the goal step length, enter custom value below and press Done").font(.body).padding()
                    
                    TextField("Step Length Goal (inches)", text: $newGoalStep)
                        .keyboardType(.numberPad)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding()
                        .focused($isTextFieldFocused)
                    
                    Button("Done") {
                        isTextFieldFocused = false
                    }
                    .padding(.top, 10)
                    
                    Text("Phone Location")
                        .font(.title2)
                        .padding(.top, 20)
                    
                    Text("Choose your phone location. Please select In Pocket/In Front for now.")
                        .font(.body)
                        .padding(.top, 20)
                    
                    Picker("Phone Location", selection: $locationPlacement) {
                        ForEach(locPlac, id: \.self) { location in
                            Text(location)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding()
                    
                    if showFeedback {
                        VStack {
                            Text("Steps Detected: \(feedbackData.steps)")
                            Text("Stride Length: \(feedbackData.strideLength, specifier: "%.2f") meters")
                            Text("Gait Constant: \(feedbackData.gaitConstant, specifier: "%.2f")")
                            Text("Does this seem accurate?")
                            HStack {
                                Button("Yes") {
                                    handleSaveCalibration()
                                }
                                .padding()
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(5)
                                
                                Button("No, recalibrate") {
                                    showFeedback = false
                                    isCollecting = false
                                    accelerometerData.removeAll()
                                }
                                .padding()
                                .background(Color.red)
                                .foregroundColor(.white)
                                .cornerRadius(5)
                            }
                        }
                        .padding()
                    }
                    
                    // Start Collecting button
                    Text("To start calibrating, press the button below. The calibration process will begin after 3 second delay. Hold your phone in up right position and start walking immediately once the process begins.")
                        .font(.body)
                        .padding(.top, 20)
                    
                    Button {
                        handleToggleCollecting()
                    } label: {
                        Text(isCollecting ? "Stop Collecting" : "Start Collecting")
                            .padding()
                            .fontWeight(.bold)
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(5)
                        
                    }.padding()
                }
            }
        }.navigationTitle("Calibration")
            .onAppear {
                if let height = Double(viewModel.currentUser?.height ?? "") {
                    goalStep = height * 0.414
                } else {
                    goalStep = userHeight * metersToInches * 0.414
                }
            }
    }
    
    private func handleToggleCollecting() {
        if !isCollecting {
            accelerometerData.removeAll()
            // begin collecting
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                self.isCollecting = true
                self.startAccelerometerUpdates()
            }
        } else {
            isCollecting = false
            motionManager.stopAccelerometerUpdates()
            handleCalibrate()
        }
    }
    
    private func handleCalibrate() {
        let yData = accelerometerData.map { $0.acceleration.y }
        let zData = accelerometerData.map { $0.acceleration.z }
        
        // MUST BE TESTED WITH PHONE FACING Z-AXIS
        if locationPlacement == "In Pocket/In Front" {
            // use z data
            
            // mean of 10 consecutive z-accelerometer data points
            let mean = zData.prefix(zData.count - 10).reduce(0, +) / Double(zData.count - 10)
            
            var steps: [Double] = []
            var lastIndex = 0
            
            // looping through zData
            // distanceThreshold: must be at least 3 data points apart to count as step --> enough time passed for another step detection
            for (index, z) in zData.enumerated() {
                // filter last 10 data points to exclude noise
                if index < zData.count - 10,
                   index - lastIndex > distanceThreshold,
                   (z < mean && zData[index - 1] > mean) || (zData[index - 1] < mean && z > mean) {
                    steps.append(Double(index))
                    lastIndex = index
                }
            }
            
            // times between steps
            let times = zip(steps.dropFirst(), steps).map { ($0 - $1) / 10.0 }
            // average times between steps
            let avTime = times.reduce(0, +) / Double(times.count)
            // average step length: 5m/number of steps (m)
            let avStepLength = distanceTraveled / Double(steps.count)
            // average step lenght in inches
            let avStepLengthInches = avStepLength * metersToInches
            // gait constant: average step length / average time between steps
            let gaitConstant = avStepLength / avTime
            print("Average Step Length: \(avStepLength)m, \(avStepLengthInches)in")
            print("Gait Constant: \(gaitConstant)")
            
            feedbackData = (steps: steps.count, strideLength: avStepLength, gaitConstant: gaitConstant)
            showFeedback = true
        }
        // MUST BE TESTED WITH PHONE'S HEAD FACING FRONT
        else if locationPlacement == "In Waist/On Side" {
            // use y data
            let mean = yData.prefix(yData.count - 10).reduce(0, +) / Double(yData.count - 10)
            
            var steps: [Double] = []
            var lastIndex = 0
            
            for (index, y) in yData.enumerated() {
                if index < yData.count - 10,
                   index - lastIndex > distanceThreshold,
                   (y < mean && yData[index - 1] > mean) || (yData[index - 1] < mean && y > mean) {
                    steps.append(Double(index))
                    lastIndex = index
                }
            }
            
            let times = zip(steps.dropFirst(), steps).map { ($0 - $1) / 10.0 } // times in seconds
            let avTime = times.reduce(0, +) / Double(times.count)
            let avStepLength = distanceTraveled / Double(steps.count)
            //            let avStepLengthInches = avStepLength * metersToInches
            let gaitConstant = avStepLength / avTime
            
            feedbackData = (steps: steps.count, strideLength: avStepLength, gaitConstant: gaitConstant)
            showFeedback = true
        }
    }
    
    private func handleSaveCalibration() {
        Task {
            let mean = locationPlacement == "In Pocket/In Front"
                ? accelerometerData.map { $0.acceleration.z }.prefix(accelerometerData.count - 10).reduce(0, +) / Double(accelerometerData.count - 10)
                : accelerometerData.map { $0.acceleration.y }.prefix(accelerometerData.count - 10).reduce(0, +) / Double(accelerometerData.count - 10)

            await viewModel.saveCalibration(gaitConstant: feedbackData.gaitConstant, threshold: mean, goalStep: newGoalStep, placement: locationPlacement)
            showFeedback = false
        }
    }
    
    private func startAccelerometerUpdates() {
        if motionManager.isAccelerometerAvailable {
            motionManager.accelerometerUpdateInterval = 0.1
            motionManager.startAccelerometerUpdates(to: .main) { data, error in
                if let data = data {
                    self.accelerometerData.append(data)
                }
            }
        }
    }
}

#Preview {
    Calibration()
}
