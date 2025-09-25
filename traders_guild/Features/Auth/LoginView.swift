import SwiftUI

struct LoginView: View {
    @Environment(\.dismiss) var dismiss
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var showPassword: Bool = false

    var body: some View {
        ZStack(alignment: .top) {
            // Background behind everything
            LinearGradient(
                colors: [AppColors.gradientBackgroundDark, AppColors.gradientBackgroundLight],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
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
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(10)
                        .padding(.horizontal)

                    // Password field
                    if showPassword {
                        TextField("Password", text: $password)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(10)
                            .padding(.horizontal)
                    } else {
                        SecureField("Password", text: $password)
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

                    // Login button
                    Button(action: {
                        print("Perform login with \(email) / \(password)")
                    }) {
                        Text("Login")
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                            .padding(.horizontal)
                    }

                    Spacer(minLength: 50)
                }
                .padding(.bottom, 32)
            }
            
            
            
            .navigationBarBackButtonHidden(true)
            .navigationBarHidden(true)
        }
        
    }
}

// MARK: - Blur helper for SwiftUI
// Works like UIVisualEffectView
struct VisualEffectBlur: UIViewRepresentable {
    var blurStyle: UIBlurEffect.Style

    func makeUIView(context: Context) -> UIVisualEffectView {
        return UIVisualEffectView(effect: UIBlurEffect(style: blurStyle))
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}

#Preview {
    LoginView()
        .environmentObject(SessionStore()) // fake logged-out session
}
