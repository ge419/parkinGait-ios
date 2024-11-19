import CoreMotion

class StepCounter {
    private let motionManager = CMMotionManager()
    private var accelerationData: [Double] = []
    private var stepCount = 0
    private var totalDistance = 0.0  // Total estimated distance
    private let sampleInterval = 0.1  // Sampling interval in seconds
    private let threshold = 1.0  // Peak threshold for step detection
    
    /// A callback triggered whenever a step is detected.
    /// - Parameters:
    ///   - stepLength: The estimated length of the step.
    ///   - stepCount: The total number of steps detected.
    ///   - totalDistance: The total distance covered in meters.
    ///   - accelerationMagnitude: The acceleration magnitude at the detected step.
    var onStepDetected: ((Double, Int, Double, Double) -> Void)?
    
    init() {
        motionManager.accelerometerUpdateInterval = sampleInterval
    }
    
    /// Starts the step counting process.
    func startStepCounting() {
        guard motionManager.isAccelerometerAvailable else {
            print("Accelerometer not available.")
            return
        }
        
        motionManager.startAccelerometerUpdates(to: OperationQueue.main) { [weak self] data, error in
            guard let self = self, let data = data, error == nil else { return }
            
            let magnitude = self.calculateNetMagnitude(acceleration: data.acceleration)
            self.accelerationData.append(magnitude)
            
            if self.accelerationData.count >= 3 {
                self.detectStep()
            }
            
            if self.accelerationData.count > 100 {
                self.accelerationData.removeFirst()
            }
        }
    }
    
    /// Stops the step counting process.
    func stopStepCounting() {
        motionManager.stopAccelerometerUpdates()
        print("Total steps counted: \(stepCount), Total distance: \(totalDistance) meters")
    }
    
    private func calculateNetMagnitude(acceleration: CMAcceleration) -> Double {
        return sqrt(pow(acceleration.x, 2) + pow(acceleration.y, 2) + pow(acceleration.z, 2))
    }
    
    private func detectStep() {
        guard accelerationData.count >= 3 else { return }
        
        let previous = accelerationData[accelerationData.count - 3]
        let current = accelerationData[accelerationData.count - 2]
        let next = accelerationData[accelerationData.count - 1]
        
        if current > previous && current > next && current > threshold {
            stepCount += 1
            let stepLength = 0.75  // Base step length in meters (adjust as needed)
            totalDistance += stepLength
            
            onStepDetected?(stepLength, stepCount, totalDistance, current)
        }
    }
}
