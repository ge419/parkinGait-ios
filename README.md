# **parkinGait-ios**

parkinGait is an iOS application designed to monitor and analyze gait patterns for individuals with Parkinson’s disease. The app utilizes the iPhone's built-in sensors, such as the accelerometer and gyroscope, to calculate step length, step count, and other gait-related metrics. It offers multiple algorithms for gait analysis and supports exporting data for further research and analysis.

---

## **Features**
- **Step Length Tracking**: Tracks and calculates step length using different algorithms.
- **Step Counting**: Counts steps and calculates total distance traveled.
- **Real-Time Data Visualization**: Displays acceleration and step length data in interactive charts.
- **Data Export(Under Development)**: Export collected gait data (accelerometer, gyroscope, and step length) to a CSV file for further analysis.
- **User-Friendly Interface**: Intuitive design for easy interaction and tracking.
- **Feedback and Statistics**: Provides feedback on user's step lengths based on calculations.

---

## **Core Components**
### **Gait Tracking Models**
1.**Step Length Calculator**: Calculates step length using device IMU sensors.
2. **Step Counter**: Tracks steps and distance using peak detection on accelerometer data.
3. **Step Length with Height**: Calculates step length by factoring in user height and stride frequency.
4. **DynamicStepCounter**: Detects step length using dynamic threshold. (INCOMPLETE; Do not proceed with this algorithm)
5. **Acceleration Magnitude**: Calculates step length using acceleration magnitude and double integration.
6. **Acceleration Magnitude FFT**: Applies Fast Fourier Transformation to the previous algorithm.

### **Data Export**
- Export gait data (timestamp, accelerometer, gyroscope, step length, etc.) to a CSV file.
- Save and share files via the Files app, email, or other apps using the iOS share sheet.

### **Interactive Visualization**
- Charts displaying real-time acceleration data or step length measurement.
- Step length visualizations for better insight into gait performance.

---

## **Setup Instructions**
### **Prerequisites**
- Xcode 16 or later.
- iOS 18.1 or later.

### **Installation**
1. Clone the repository:
   ```bash
   git clone https://github.com/your-username/parkinGait-ios.git
   ```
2. Open the project in Xcode:
3. Build and run the app on a physical device.
4. If you run into errors regarding Xcode, check if the bundle identifier is correct.

---

## **How to Use**
1. **Step Length Tracking**:
   - Choose one of the gait tracking models from the main page.
   - Start tracking to calculate step length in real time.
   - View real-time acceleration and step data via charts.

2. **Step Counting**:
   - Navigate to the **Step Counter** view.
   - Start tracking steps and distance.

3. **Export Data**:
   - After tracking, press the **Export Data** button.
   - Save the CSV file to Files or share it via email, AirDrop, etc.
  

# Step Length Calculation for Parkinson's Patients

## 1. Application
Current mobile application on iOS supports multiple algorithms for testing purposes. See description above to get started.

## 2. Variables
This section discusses the variables that affect step length calculation. There may be more variables that had not been considered so far that influences step length calculation.
- **Position of the device**: Of all the variabes, position of the device impacts the step length calculation the most. In most cases, it was assumed that the device will be attached to the user's ankle. Make sure the orientation of the phone is clear (unless using acceleration magnitude) before making adjustments to the algorithm or developing a new algorithm.
- **Acceleration**: Based on the device's orientation, one of x, y, z-acceleration, or combination of all three can be used. Acceleration is the key variable to the step length calculation process, as the calculation step is usually associated with time a step was taken and the user's walking speed.
- **Gravity**: When using acceleration, the effect of gravity must be taken under consideration. Different algorithms have different approaches to dealing with gravity, but it's optimal to remove all effect of gravity before further analysis is done. Removing gravity can be easily performed by projecting the acceleration to gravity.
- **Height**: In some cases, user's height can be used to help calculate step lengths, but relying on height could introduce biases to step lengths. Use this to estimate the user's target step length.
- **Walking speed**: Some algorithms show different results if walking speed is altered. 
- **Static variables**: Any fixed values used in the algorithm could lead to lack of customization for different users. Since walking differs greatly from user to user, it is highly recommended that static variables are avoided. It is almost impossible to find the optimal static value that can generally fit most of the users. There is also no specific way of finding these values -- exhaustively testing different values will greatly slow down progress. Most common example is threshold for peak detection. 
- **Device/language-specific issues**: Depending on which device is used for testing, there could be differences in results. For example, React Native application showed different results from an iOS application that had the exact same functionality. Data processing is dealt differently in different programming languages, so it is important to synchonize the results on different devices as much as possible.
- **Testing conditions**: There should be a set testing condition to test different algorithms. Testing the same algorithm on different people could produce drastically different results. Synchronize the testing conditions and instructions to ensure consistent testing results.



## 3. Algorithms

### 3.1 Gait Constant and Dynamic Thresholding (React)
This algorithm utilizes acceleration data to detect peaks, and estimates step length using a gait constant. It was originally implemented in React (Expo), and was converted to Swift and Kotlin to develop native application for each platform.

#### 3.1.1 Step Detection Mechanism
- Calibration to calcualte the gait constant of the user. This information is stored in the database for future use. Can be recalibrated and updated if needed.
- Takes user's height and target step length as input.
- Accelerometer data is collected (x, y, z acceleration) at 10 Hz. 
- Data is smoothed using a window of 5 samples.
- Assuming Pocket/In Front Placement (Z-Axis based detection), the algorithm monitores when the z-axis acceleration crosses a threshold.
- Ensure peaks are sufficiently spaced apart to avoid false positives and store timestamps of peak detection.
- Once two consecutive peaks are detected, step length is computed as:
$Step Length = (Time Between Peaks) * Gait Constant * 39.3701$. 39.3701 is the number of inches per meter.
- Uses vibration and audio to give feedback on the step taken compared to the target step length (e.g. Over-stepping, under-stepping).

#### 3.1.2 Peak Detection
Dynamic thresholding is used to differentiate actual steps from random accelerometer fluctuations. See the code below:
```
const standardDeviation = (arr) => {
  const avg = arr.reduce((sum, val) => sum + val, 0) / arr.length;
  const sumOfSquares = arr.reduce(
    (sum, val) => sum + (val - avg) * (val - avg),
    0
  );
  return Math.sqrt(sumOfSquares / arr.length);
};

const mean = average(zData);
const zStdDev = standardDeviation(zData);
const dynamicThresholdZ = mean + zStdDev * 0.5;
```
This function computes the standard deviation of accelerometer readings, and calculates the dynamic threshold using the standard deviation. This helps to accomodate with situations where the user has different walking speeds for different steps. In peak detection process, current acceleration must cross the detection threshold and the dynamic threshold.

#### 3.1.3 Gait Constant and Calibration
In calibration step, user walks five meters and the number of steps the user is taking is detected. Using this data, average step distance can be calculated ($\frac{5}{number\ of \ steps}$). Gait constant is then found by dividing the average step length and dividing it by the average step time. The mean of the data, which is used as the detection threshold is saved to the database along with the gait constant.
$$
Gait\ Constant = \frac{Average\ Step\ Length}{Average\ Step\ Time}
$$
This shows that gait constant is essentially an estimate of the user's walking speed. This makes sense as the distance traveled (step length) can be calculated by multiplying the delta time (time between peaks(steps)) and the speed of the user (gait constant).

#### 3.1.4 Insights
- Dynamic Thresholding: Able to adapt to different walking patterns (e.g. slow or fast paces).
- Gait Constant Calibration: Allows customization in step length calculation per user.

#### 3.1.5 Limitations
- Fixed Gait Constant: It is not guaranteed that the users will be walking at the same speed at all times.
- Phone placement: There is no information on how this algorithm was tested.
- Test Results: There was no test results provided by the developer of this algorithm. Tests were conducted according to instructions given, but were not successful. Assuming the phone was hand-held near waist and I let the phone move vertically as I walked, the test results for this algorithm show that there is constant trend in step length esitmates, but were not necessarily accurate. In my case, the expected step length was 30 inches, but the detected step lengths were around 18-24 inches. Testing with the phone in pockets were not successful at all.

### 3.2 Device Attached to Ankle (iOS)
This Swift implementation of step length estimation is based on Zero Velocity Updates (ZVU) and sensor fusion using IMU data (accelerometer, gyroscope, and quaternion-based gravity compensation)**. The algorithm was adapted from a previous C++ (Arduino) implementation and optimized for iOS. See [here](https://github.com/mayarim/Park_PTD) for more details.

#### 3.2.1 IMU Initialization and Data Processing
- Uses `CoreMotion` to collect accelerometer, gyroscope, and orientation quaternion data.
- Gravity compensation is performed using quaternion-based orientation tracking. This allows only motion-related acceleration is used.
- Zero Velocity Updates (ZVU) determine when a step has occurred.
- Gravity projection ensures acceleration values are not affected by orientation drift.
- ZVU detects if motion has stopped, which helps identify steps.

#### 3.2.2 Step Detection and Distance Calculation
- The ZVU algorithm determines when motion has stopped, which helps reset velocity and position estimates to prevent drift. 
- When a zero-velocity event is detected, the function resets the position estimate.
- If motion is detected, step length is computed using double integration of acceleration.
- Acceleration is integrated to compute velocity.
- Velocity is integrated to estimate displacement.
- If the estimated displacement exceeds a threshold, a step is registered.

#### 3.2.3 Insights
- Sensor fusion with quaternion-based gravity compensation: Uses quaternion-based gravity extraction to remove orientation-dependent noise from acceleration data.
- Zero Velocity Updates (ZVU) for step detection: Ensures that velocity resets when the user stops, preventing error accumulation.
- No need of calibrated user-specific data: This requires no calibration or customization, allowing simpler steps to calcuate step lengths from user perspective.
- This code also includes a mechanism to export the collected data as a csv file.

#### 3.2.4 Limitations
- Integration-based step length is prone to drift: Small sensor noise accumulates over time, leading to inaccurate distance estimation. Since this algorithm relies entirely on integration to calculate step length, the test results have high variance.
- Too much fixed variables to consider: Migrating from a custom-made device to a smartphone caused problems since the fixed values used in the original algorithm did not work with the iOS application. For example, threshold values for distance, acceleration, and gyroscope had to be adjusted. There was no specific trend in step length calculation when multiple different values were used for thresholds. ZVU also requires threshold values that need adjustment.
- Test results:

#### 3.2.5 Suggestion
- Test the previous team's algorithm with their device.

### 3.3 Acceleration Magnitude
This algorithm detects steps and estimates step length by analyzing the magnitude of acceleration and using a positive-negative acceleration spark detection method. It leverages integral-based motion tracking and gravity compensation while storing motion data for further analysis. Unlike previous implementations, it explicitly tracks step timing and applies low-pass filtering for smoother acceleration signals.

#### 3.3.1 Step Detection and Step Length Calculation
- The algorithm first extracts gravity components from the quaternion orientation to remove static gravity effects from raw acceleration data.
- Acceleration magnitude is calculated for each sample using the following function: $ AccleMag = \sqrt{(a_x^2 + a_y^2+a_z^2)} $.
- This value is compared to a threshold which is used to determine whether there was a positive or negative spark.
- Detects high acceleration peaks (positive spark) followed by low acceleration dips (negative spark). A step is only considered valid if the time between positive and negative spikes is above a minimum threshold (0.5s) but not excessively long (above 2.0s). A threshold in acceleration magnitude is used to determin positive and negative sparks.
- If a previous timestamp exists, the acceleration is integrated to compute velocity, and velocity is integrated to compute position. This step tracks displacement over time and calculates step length.
- After computing step length, integration is reset to avoid error accumulation. The step count is incremented, and the timestamp of the step is stored.

#### 3.3.2 Insights
- Unlike traditional axis-specific peak detection, this approach tracks overall acceleration magnitude, which makes it flexible in terms of the device's placement. 
- Helps capture strong impacts from foot strikes.
- Step detection succeeds with high accuracy.

#### 3.3.3 Limitations
- Similar to Algorithm 3.2, Integration drift can accumulate over time. Since step length relies on integrating acceleration twice, sensor drift and numerical errors accumulate over multiple steps. A user taking long walks may see increasing step length errors over time.
- Threshold-based step detection might miss subtle movements. The `ACCEL_THRESHOLD` of 10.0 is static, meaning slow or shuffling steps may be missed, or very forceful steps might be detected multiple times.
- High chance of detection errors since a fixed threshold value is used when the actual value of acceleration magnitude may vary greatly due to noise.
- The use of static values such as acceleration magnitude threshold and min/max step time thresholds, could neglect variance between different users. This results in lower accuracy of the calculated step lengths.

### 3.4 Acceleration Magnitude with Fast Fourier Transformation
This algorithm introduces Fast Fourier Transform (FFT) filtering to improve step detection and step length estimation by removing high-frequency noise from acceleration data. It employs spark-based step detection (positive and negative acceleration peaks) and statistical feedback on step accuracy compared to a target step length. This is the only algorithm that does not provide real-time feedback.

#### 3.4.1 Step Detection and Step Length Calculation
- The algorithm continuously collects acceleration and gyroscope data.
- Once the user stops walking (and presses stop walking button), data collection stops and data processing begins.
- Gravity is removed to isolate motion-related acceleration similar to Algorithm 3.3.
- Acceleration magnitude is calculated using $ AccleMag = \sqrt{(a_x^2 + a_y^2+a_z^2)} $. 
- Fast Fourier Transform and low-pass filter is applied to remove high frequency noise, and frequencies above `CUTOFF_FREQUENCY` are set to zero.
- Inverse FFT reconstructs the filtered acceleration signal for cleaner step detection. Note that the resulting filtered acceleration magnitude may be negative.
- Similar to Algorithm 3.3, Step start (positive spark) is detected when acceleration exceeds `ACCEL_THRESHOLD`. Step end (negative spark) is detected when acceleration drops below `ACCEL_THRESHOLD`. A step is considered valid if its duration falls between MIN_DELTA_TIME (0.5s) and MAX_DELTA_TIME (2.0s).
- If a previous timestamp exists, the acceleration is integrated to compute velocity, and velocity is integrated to compute position. This step tracks displacement over time and calculates step length.
- After computing step length, integration is reset to avoid error accumulation. The step count is incremented, and the timestamp of the step is stored.
- Average step length and variance are computed from detected steps and step length accuracy is compared against `TARGET_STEP_LENGTH`. The computed accuracy is used to provide feedback on the steps taken (whether to shorten or increase steps). Current cutoff for good steps is 90%.

#### 3.4.2 Insights
- FFT filtering removes high frequency noise for cleaner step detection as it eliminates unwanted accelerometer noise. This means vibrations from phone movements that are not related to walking or taking steps will be filtered out.
- Analysis after all data has been collected could be useful to observe a trend in the dataset as a whole.
- Feedback based on accuracy doesn't require perfect precision for each step, but leaves room for uncaptured noise that could have remained after data processing.

#### 3.4.3 Limitations
- Since FFT is applied after all data has been collected, real-time analysis is not possible for this algorithm. It is possible to implement real-time FFT, but could lead to latency since FFT requires a set window size (number of samples). 
- Similar to Algorithm 3.3, threshold-based step detection might miss subtle movements. The `ACCEL_THRESHOLD` of 10.0 is static, meaning slow or shuffling steps may be missed, or very forceful steps might be detected multiple times.
- Any output to the user is possible only after all steps have been taken. 

## 4. Suggestions
Here's the roadmap for further improving this project.

### 4.1 Agenda
Here are some ideas to think about in terms of how this project should be developed in the future.

- Flexible, adaptive algorithm: Capturing a general trend on walking behavior is extremely difficult. Make the algorithm be flexible as much as possible so that it could handle individual differences in walking behavior. 
- Remove fixed values: Again, make the algorithm flexible. Relying on fixed values proved to produce incorrect results even with a slight change in testing conditions.
- Post-calculation: Instead of real-time calculation, post-calculation doesn't require data to be perfectly correct. Showing a trend of step length is enough and more reliable way of giving feedback.

### 4.2 Consideration
Consider the following elements for future development:

- Apply adaptive thresholding for step detection (see Algo 3.1). Utilize standard deviation based thresholding and adjust based on walking speed variations, individual gait differences, and sensor placement differences.
- Adaptive filtering: Use other filters such as Kalman filter which uses both acceleration and gyroscope data.
- Calibration: Re-introduce calibration so that accuracy on step length calculation can be improved. Capturing a general trend on walking behavior is extremely difficult. 
- Replace double integration with a different method. Double integration showed to cause drift over multiple steps where step lengths keep increasing. 

### 4.3 Recommendation (Future Roadmap)
I recommend starting from acceleration magnitude with FFT. This algorithm has functional data processing and exporting mechanisms, and is capable of handling step detection well (given that a user-specific threshold is being used).

The current issue with this algorithm is that the step length calculation process isn't solid. Try to implement different approachs to test which algorithm has high accuracy and sensitivity. There are also a lot of hardcoded values that need to be adjusted based on users' walking styles in the calibration process.

#### 4.3.1 Data Processing and Calibration
- Use acceleration magnitude to detect steps, and FFT to smooth the output. Acceleration magnitude is useful as it doesn't take direction into account.
- Removing gravity is also done in the current algorithm. This will eliminate the effect of gravity no matter the orientation of the phone as it uses quaternion to check the phone's orientation and projects acceleration onto gravity.
- Introduce calibration to adjust for different walking styles of users. Calibration should extract gait constant and user-specific threshold for peak detection, and should be saved to the database for later use. (See next section for more on user-specific threshold)

#### 4.3.2 Step Detection
- Steps are detected using peak detection algorithm. When there is a peak in acceleration magnitude above certain threshold, we assume a step has occurred. There may be other approaches to do step detection, but peak detection have proved to be well-performing so far.
- User-specific thresholds mean a dynamic threshold that could handle the variances in the average acceleration magnitude value of each user. This should be calculated in the calibration process. Algorithm 3.1 has some resource regarding a dynamic threshold. Using insight from 3.1 will help accommodate the differences between users well.

#### 4.3.3 Step Length Calculation
- Currenly step length is calculated using double integration. This causes drift, and is not a reliable way of estimating step length.
- Instead, use gait constant (user's walking speed) along with delta time between start and end of a peak. There may be more adjustments required to make the result accurate, but this is a good starting point to consider.

#### 4.3.4 Feedback and Statistics
- The first few algorithms (3.1 and 3.2) have metronomes to help users keep their pace as well as visual and audio(vibration) feedback that notifies users if their steps are too short or long. Build upon this code to provide users feedback on the steps taken.
- Post-calculation leaves much room for accuracy as not all steps have to be accurate. Capture a general trend in the steps using average and standard deviation. While the current algorithm contains code to calculate the statistics, this can be improved by implementing and testing different ways to calculate accuracy. 

#### 4.3.4 Testing
- In the testing process, measure the steps you are actually taking, and compare to the results you see calculated. Test for small/large/fast/slow steps to make sure the algorithm is capable of handling user's gait in any case.
- It's important that testing codnitions are decided and maintained before testing starts. For example, walking with or without shoes on may result in different results for the same walking pattern.
- The position of the phone for algorithm 3.3 and 3.4 will not matter as long as they are strapped near the ankle. The algorithm is capable of determining the phone's orientation, and the correlating gravity will also be eliminated. 

#### 4.3.5 Miscellaneous 
- Supporting extreme behaviors of waking (e.g. shuffling, lunge, jumping, running) simultaneously may not be viable. These would require calibration beforehand so that t he algorithm is aware of the abnormal walking activity
- Collect and store data for each user, and update the variables calculated in the calibration process. Gait constant and dynamic thresholds can be greatly improved with enough test data. Applying the walking trend of a user into the algorithm is crucial for making the algorithm accurate.
- User's height could be leveraged to help calculate step lenghts, but becareful not to rely on height as it could produce biased results.
