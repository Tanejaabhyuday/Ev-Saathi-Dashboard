import SwiftUI

// MARK: - AdminProfileView
// Shows the logged-in admin's profile and provides logout / change-password.

struct AdminProfileView: View {

    @EnvironmentObject private var authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showChangePassword = false
    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""
    @State private var passwordMessage: String = ""
    @State private var showLogoutConfirm = false

    var body: some View {
        NavigationView {
            List {

                // MARK: Avatar + Name
                Section {
                    HStack(spacing: 16) {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 64, height: 64)
                            .overlay(
                                Text(authVM.currentUser?.initials ?? "?")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.white)
                            )
                        VStack(alignment: .leading, spacing: 4) {
                            Text(authVM.currentUser?.name ?? "Administrator")
                                .font(.headline)
                            Text(authVM.currentUser?.email ?? "")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            if let role = authVM.currentUser?.role {
                                Text(role.displayName)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.orange.opacity(0.12))
                                    .foregroundColor(.orange)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.vertical, 6)
                }

                // MARK: Account actions
                Section("Account") {
                    Button {
                        showChangePassword.toggle()
                    } label: {
                        Label("Change Password", systemImage: "lock.rotation")
                    }

                    if showChangePassword {
                        VStack(spacing: 10) {
                            SecureField("New Password", text: $newPassword)
                                .textContentType(.newPassword)
                            SecureField("Confirm Password", text: $confirmPassword)
                            if !passwordMessage.isEmpty {
                                Text(passwordMessage)
                                    .font(.caption)
                                    .foregroundColor(passwordMessage.contains("success") ? .green : .red)
                            }
                            Button("Update Password") {
                                handlePasswordChange()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.orange)
                            .disabled(newPassword.count < 6 || newPassword != confirmPassword)
                        }
                        .padding(.vertical, 4)
                    }
                }

                // MARK: Demo admin credentials
                Section("Demo Accounts") {
                    ForEach(SeedService.demoAdmins, id: \.email) { admin in
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(admin.name).font(.subheadline.weight(.medium))
                                Spacer()
                                Text(admin.role.displayName)
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.orange.opacity(0.1))
                                    .foregroundColor(.orange)
                                    .cornerRadius(4)
                            }
                            Text(admin.email).font(.caption).foregroundColor(.secondary)
                            Text("Password: \(admin.password)").font(.caption).foregroundColor(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }

                // MARK: Sign out
                Section {
                    Button(role: .destructive) {
                        showLogoutConfirm = true
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog("Sign out of EV Saathi?", isPresented: $showLogoutConfirm, titleVisibility: .visible) {
                Button("Sign Out", role: .destructive) {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        authVM.logout()
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    private func handlePasswordChange() {
        guard newPassword == confirmPassword else {
            passwordMessage = "Passwords do not match."
            return
        }
        guard newPassword.count >= 6 else {
            passwordMessage = "Password must be at least 6 characters."
            return
        }
        authVM.changePassword(newPassword: newPassword) { success, message in
            passwordMessage = message
            if success {
                newPassword = ""
                confirmPassword = ""
                showChangePassword = false
            }
        }
    }
}
