import SwiftUI

// MARK: - LoginView

struct LoginView: View {

    @EnvironmentObject private var authVM: AuthViewModel

    @State private var email: String    = ""
    @State private var password: String = ""
    @State private var showPassword: Bool   = false
    @State private var showDemoSheet: Bool  = false
    @State private var seedResult: String   = ""
    @State private var isSeeding: Bool      = false

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color(hex: "#0F172A") ?? .black, Color(hex: "#1E293B") ?? .gray],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 32) {

                    // MARK: Logo
                    VStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.orange)
                                .frame(width: 72, height: 72)
                                .shadow(color: .orange.opacity(0.4), radius: 20)
                            Image(systemName: "bus.fill")
                                .font(.system(size: 36))
                                .foregroundColor(.white)
                        }
                        Text("EV Saathi")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                        Text("Fleet Manager Portal")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 60)

                    // MARK: Card
                    VStack(spacing: 20) {
                        Text("Administrator Login")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        // Email
                        VStack(alignment: .leading, spacing: 6) {
                            Label("Email", systemImage: "envelope.fill")
                                .font(.caption)
                                .foregroundColor(.gray)
                            TextField("admin@evosaathi.com", text: $email)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .autocorrectionDisabled()
                                .padding()
                                .background(Color.white.opacity(0.08))
                                .cornerRadius(12)
                                .foregroundColor(.white)
                                .tint(.orange)
                        }

                        // Password
                        VStack(alignment: .leading, spacing: 6) {
                            Label("Password", systemImage: "lock.fill")
                                .font(.caption)
                                .foregroundColor(.gray)
                            HStack {
                                if showPassword {
                                    TextField("••••••••", text: $password)
                                        .autocapitalization(.none)
                                        .autocorrectionDisabled()
                                } else {
                                    SecureField("••••••••", text: $password)
                                }
                            }
                            .padding()
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(12)
                            .foregroundColor(.white)
                            .tint(.orange)
                            .overlay(alignment: .trailing) {
                                Button {
                                    showPassword.toggle()
                                } label: {
                                    Image(systemName: showPassword ? "eye.slash" : "eye")
                                        .foregroundColor(.gray)
                                        .padding(.trailing, 12)
                                }
                            }
                        }

                        // Error message
                        if let err = authVM.errorMessage {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                Text(err)
                                    .font(.caption)
                            }
                            .foregroundColor(.red)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                        }

                        // Sign In Button
                        Button {
                            authVM.login(email: email, password: password)
                        } label: {
                            Group {
                                if authVM.isLoading {
                                    ProgressView().tint(.white)
                                } else {
                                    Label("Sign In", systemImage: "arrow.right.circle.fill")
                                        .font(.headline)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.orange)
                            .cornerRadius(14)
                            .foregroundColor(.white)
                        }
                        .disabled(authVM.isLoading || email.isEmpty || password.isEmpty)

                        Divider().overlay(Color.gray.opacity(0.3))

                        // Demo credentials
                        Button {
                            showDemoSheet = true
                        } label: {
                            Label("View Demo Credentials", systemImage: "info.circle")
                                .font(.subheadline)
                                .foregroundColor(.orange.opacity(0.8))
                        }
                    }
                    .padding(24)
                    .background(.ultraThinMaterial)
                    .cornerRadius(24)
                    .padding(.horizontal)

                    // First-time setup seed button
                    VStack(spacing: 8) {
                        Text("First time? Seed demo data into Firebase:")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Button {
                            isSeeding = true
                            seedResult = ""
                            SeedService.shared.seedIfNeeded { result in
                                DispatchQueue.main.async {
                                    seedResult = result
                                    isSeeding = false
                                }
                            }
                        } label: {
                            Group {
                                if isSeeding {
                                    ProgressView().tint(.white)
                                } else {
                                    Label("Initialize Demo Data", systemImage: "server.rack")
                                }
                            }
                            .font(.caption)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(10)
                            .foregroundColor(.white)
                        }
                        if !seedResult.isEmpty {
                            Text(seedResult)
                                .font(.caption2)
                                .foregroundColor(.green)
                                .multilineTextAlignment(.center)
                                .padding(.top, 4)
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
        }
        .sheet(isPresented: $showDemoSheet) {
            DemoCredentialsSheet()
        }
    }
}

// MARK: - Demo Credentials Sheet

private struct DemoCredentialsSheet: View {

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                Section {
                    Text("These 3 accounts are created when you tap \"Initialize Demo Data\".")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                ForEach(SeedService.demoAdmins, id: \.email) { admin in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(admin.name).font(.headline)
                            Spacer()
                            Text(admin.role.displayName)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(admin.role == .superadmin ? Color.orange.opacity(0.15) : Color.blue.opacity(0.12))
                                .foregroundColor(admin.role == .superadmin ? .orange : .blue)
                                .cornerRadius(6)
                        }
                        Text("📧 \(admin.email)").font(.caption).foregroundColor(.secondary)
                        Text("🔑 \(admin.password)").font(.caption).foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Demo Credentials")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
