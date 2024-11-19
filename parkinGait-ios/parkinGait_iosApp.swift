//
//  parkinGait_iosApp.swift
//  parkinGait-ios
//
//  Created by 신창민 on 11/15/24.
//

//import SwiftUI
//import FirebaseCore
//
//@main
//struct parkinGait_iosApp: App {
//    var body: some Scene {
//        WindowGroup {
//            ContentView()
//        }
//    }
//}
import SwiftUI
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    FirebaseApp.configure()
    return true
  }
}

@main
struct parkinGait_iosApp: App {
    @StateObject var viewModel = AuthViewModel()
  // register app delegate for Firebase setup
  @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

  var body: some Scene {
    WindowGroup {
      NavigationView {
        ContentView()
              .environmentObject(viewModel)
      }
    }
  }
}
