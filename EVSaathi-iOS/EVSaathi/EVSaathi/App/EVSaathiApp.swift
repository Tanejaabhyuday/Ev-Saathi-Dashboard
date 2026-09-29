import SwiftUI
import FirebaseCore

// MARK: - App Entry Point

@main
struct EVSaathiApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

// MARK: - AppDelegate (Firebase init)

class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Configure Firebase (reads GoogleService-Info.plist)
        FirebaseApp.configure()
        return true
    }
}
