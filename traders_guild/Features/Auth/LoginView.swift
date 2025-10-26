import SwiftUI

struct LoginView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState  // ✅ Add AppState
    
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var showPassword: Bool = false
    @State private var isLoggingIn: Bool = false

    var body: some View {
        ZStack(alignment: .top) {
            // Background behind everything
            StaticAuthBackgroundView()
            
            ZStack {
                // Blur-only background
                VisualEffectBlur(blurStyle: .systemUltraThinMaterial)
                    .frame(height: 44)
                    .edgesIgnoringSafeArea(.top)

                HStack {
                    // Back button
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                    .disabled(isLoggingIn)  // ✅ Disable during login

                    Spacer()

                    // Center title
                    Text("TG")
                        .font(.largeTitle)
                        .bold()
                        .foregroundColor(.primary)

                    Spacer()

                    // Placeholder to keep title centered
                    Rectangle()
                        .frame(width: 44)
                        .opacity(0)
                }
                .padding(.horizontal)
            }

            // MARK: - Scrollable login content
            ScrollView {
                VStack(spacing: 20) {
                    Spacer().frame(height: 44)
                    Text("Login with your email to access your account.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 32)
                        .padding(.horizontal)

                    // Email field
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                        .disabled(isLoggingIn)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(10)
                        .padding(.horizontal)

                    // Password field
                    if showPassword {
                        TextField("Password", text: $password)
                            .disabled(isLoggingIn)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(10)
                            .padding(.horizontal)
                    } else {
                        SecureField("Password", text: $password)
                            .disabled(isLoggingIn)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(10)
                            .padding(.horizontal)
                    }

                    // Show/hide password
                    Button(action: { showPassword.toggle() }) {
                        Text(showPassword ? "Hide Password" : "Show Password")
                            .font(.footnote)
                            .foregroundColor(.blue)
                    }
                    .disabled(isLoggingIn)

                    // Login button
                    Button(action: {
                        Task {
                            await handleLogin()
                        }
                    }) {
                        HStack {
                            if isLoggingIn {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            }
                            Text(isLoggingIn ? "Logging in..." : "Login")
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(canLogin ? Color.blue : Color.gray)
                        .cornerRadius(10)
                        .padding(.horizontal)
                    }
                    .disabled(!canLogin || isLoggingIn)  // ✅ Disable if fields empty or logging in

                    Spacer(minLength: 50)
                }
                .padding(.bottom, 32)
            }
            .navigationBarBackButtonHidden(true)
            .navigationBarHidden(true)
        }
    }
    
    // MARK: - Helpers
    
    private var canLogin: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty &&
        !password.isEmpty
    }
    
    private func handleLogin() async {
        isLoggingIn = true
        
        do {
            try await appState.login(email: email, password: password)
            // Login successful - AppState will handle navigation
            dismiss()
        } catch {
            // Error automatically shown by global alert
            isLoggingIn = false
        }
    }
}

// MARK: - Blur helper for SwiftUI
struct VisualEffectBlur: UIViewRepresentable {
    var blurStyle: UIBlurEffect.Style

    func makeUIView(context: Context) -> UIVisualEffectView {
        return UIVisualEffectView(effect: UIBlurEffect(style: blurStyle))
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}

#Preview {
    LoginView()
        .environmentObject(AppState())
}
