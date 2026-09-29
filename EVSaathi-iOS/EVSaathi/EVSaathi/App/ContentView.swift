import SwiftUI

// MARK: - ContentView (Auth Gate)
// Switches between LoginView and the main app depending on auth state.

struct ContentView: View {

    @StateObject private var authVM = AuthViewModel()

    var body: some View {
        Group {
            if authVM.isCheckingAuth {
                // Splash while Firebase checks persisted session
                SplashView()
            } else if authVM.isLoggedIn {
                MainTabView()
                    .environmentObject(authVM)
            } else {
                LoginView()
                    .environmentObject(authVM)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authVM.isLoggedIn)
        .animation(.easeInOut(duration: 0.3), value: authVM.isCheckingAuth)
    }
}

// MARK: - SplashView

private struct SplashView: View {
    var body: some View {
        ZStack {
            Color(hex: "#0F172A") ?? Color.black
            VStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.orange)
                        .frame(width: 72, height: 72)
                    Image(systemName: "bus.fill")
                        .font(.system(size: 36))
                        .foregroundColor(.white)
                }
                Text("EV Saathi")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                Text("Fleet Manager")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                ProgressView()
                    .tint(.orange)
                    .padding(.top, 8)
            }
        }
        .ignoresSafeArea()
    }
}
