# **parkinGait-ios**

parkinGait is an iOS application designed to monitor and analyze gait patterns for individuals with Parkinson’s disease. The app utilizes the iPhone's built-in sensors, such as the accelerometer and gyroscope, to calculate step length, step count, and other gait-related metrics. It offers multiple algorithms for gait analysis and supports exporting data for further research and analysis.

---

## **Features**
- **Step Length Tracking**: Tracks and calculates step length using different algorithms.
- **Step Counting**: Counts steps and calculates total distance traveled.
- **Real-Time Data Visualization**: Displays acceleration and step length data in interactive charts.
- **Data Export(Under Development)**: Export collected gait data (accelerometer, gyroscope, and step length) to a CSV file for further analysis.
- **User-Friendly Interface**: Intuitive design for easy interaction and tracking.

---

## **Core Components**
### **Gait Tracking Models**
1. **Step Counter**: Tracks steps and distance using peak detection on accelerometer data.
2. **Step Length Calculator**: Calculates step length using device IMU sensors.
3. **Step Length with Height**: Calculates step length by factoring in user height and stride frequency.

### **Data Export(Under Development)**
- Export gait data (timestamp, accelerometer, gyroscope, and step length) to a CSV file.
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

