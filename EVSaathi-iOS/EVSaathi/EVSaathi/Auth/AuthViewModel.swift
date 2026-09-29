import Foundation
import FirebaseAuth
import Combine

// MARK: - AuthViewModel
// Manages Firebase Auth state, login/logout, and the current user profile.

final class AuthViewModel: ObservableObject {

    @Published var isLoggedIn: Bool = false
    @Published var isCheckingAuth: Bool = true    // true while Firebase checks stored session
    @Published var currentUser: UserModel?
    @Published var errorMessage: String?
    @Published var isLoading: Bool = false

    private var authStateHandle: AuthStateDidChangeListenerHandle?

    init() {
        // Listen for auth state changes (handles session persistence automatically)
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, firebaseUser in
            guard let self = self else { return }
            Task { @MainActor in
                if let firebaseUser = firebaseUser {
                    // Fetch Firestore profile
                    self.fetchUserProfile(uid: firebaseUser.uid)
                    self.isLoggedIn = true
                } else {
                    self.currentUser = nil
                    self.isLoggedIn = false
                }
                self.isCheckingAuth = false
            }
        }
    }

    deinit {
        if let handle = authStateHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

    // MARK: - Login

    func login(email: String, password: String) {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please enter your email and password."
            return
        }
        isLoading = true
        errorMessage = nil

        Auth.auth().signIn(withEmail: email, password: password) { [weak self] result, error in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.isLoading = false
                if let error = error {
                    self.errorMessage = self.friendlyError(error)
                }
                // isLoggedIn is set automatically by the auth state listener
            }
        }
    }

    // MARK: - Logout

    func logout() {
        try? Auth.auth().signOut()
        currentUser = nil
    }

    // MARK: - Password Change

    func changePassword(newPassword: String, completion: @escaping (Bool, String) -> Void) {
        Auth.auth().currentUser?.updatePassword(to: newPassword) { error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(false, error.localizedDescription)
                } else {
                    completion(true, "Password updated successfully.")
                }
            }
        }
    }

    // MARK: - Private Helpers

    private func fetchUserProfile(uid: String) {
        FirestoreService.shared.fetchUser(uid: uid) { [weak self] user in
            Task { @MainActor [weak self] in
                self?.currentUser = user
            }
        }
    }

    private func friendlyError(_ error: Error) -> String {
        let nsError = error as NSError
        switch AuthErrorCode(rawValue: nsError.code) {
        case .wrongPassword, .invalidCredential:
            return "Incorrect email or password."
        case .userNotFound:
            return "No account found with this email."
        case .networkError:
            return "Network error. Please check your connection."
        case .tooManyRequests:
            return "Too many attempts. Please try again later."
        default:
            return error.localizedDescription
        }
    }
}
