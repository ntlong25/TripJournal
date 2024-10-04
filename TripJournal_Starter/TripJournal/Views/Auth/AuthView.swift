import SwiftUI

struct AuthView: View {
    /// Describes validation errors that might occur locally in the form.
    struct ValidationError: LocalizedError {
        var errorDescription: String?

        static let emptyUsername = Self(errorDescription: String("Username is required."))
        static let emptyPassword = Self(errorDescription: String("Password is required."))
        static let emptyEmail = Self(errorDescription: String("Email is required."))
        static let emptyFullname = Self(errorDescription: String("Full name is required."))
    }

    @State private var isLogin = false
    @State private var email: String = ""
    @State private var fullName: String = ""
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var isLoading = false
    @State private var error: Error?

    @Environment(\.journalService) private var journalService

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .leading) {
            LinearGradient.background
                .edgesIgnoringSafeArea(.all)
            VStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Make your")
                        .font(.system(size: 36, weight: .light))
                        .foregroundStyle(.white)
                    Text("JOURNEY")
                        .font(.system(size: 56, weight: .bold))
                        .foregroundStyle(.link.opacity(0.6))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Spacer()
                
                VStack {
                    AsyncImage(url: URL(string: "https://cdn.pixabay.com/photo/2020/01/24/21/33/city-4791269_960_720.png")) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 350)
                    } placeholder: {
                        ProgressView()
                    }
                    
                    Spacer()
                    
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack {
                Spacer()
                
                VStack(alignment: .center, spacing: 20) {
                    Text(isLogin ? "Log In" : "Create Account")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.bottom, 30)
                    
                    VStack(spacing: 20) {
                        inputs()
                    }
                    .padding(.horizontal, 20)
                    
                    buttons()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .padding(.bottom, 20)
                .background(.white)
                .cornerRadius(20, corners: [.topLeft, .topRight])
            }
        }
        .edgesIgnoringSafeArea(.bottom)
        .loadingOverlay(isLoading)
        .alert(error: $error)
        .onAppear {
            checkTokenExpiration()
        }
    }

    // MARK: - Views

    private func header() -> some View {
        VStack {
            AsyncImage(url: URL(string: "https://cdn.pixabay.com/photo/2020/01/24/21/33/city-4791269_960_720.png")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 350)
            } placeholder: {
                ProgressView()
            }
            
            Spacer()
        }
        
    }

    @ViewBuilder
    private func inputs() -> some View {
        if !isLogin {
            TextField("Full name", text: $fullName)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .textContentType(.password)
            TextField("Email", text: $email)
                .keyboardType(.emailAddress)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .textContentType(.password)
        }
        
        TextField("Username", text: $username)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .textContentType(.username)
        SecureField("Password", text: $password)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .textContentType(.password)
    }

    private func buttons() -> some View {
        VStack(alignment: .center, spacing: 10) {
            Button(
                action: {
                    Task {
                        isLogin ? await logIn() : await register()
                    }
                },
                label: {
                    Text(isLogin ? "Log In" : "Create Account")
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }
            )
            .padding(.horizontal, 20)
            .padding(.top, 30)
            
            Button(action: {
                isLogin.toggle()
            }) {
                Text(isLogin ? "Don't have an account? Register" : "Already have an account? Log in")
                    .foregroundColor(.blue)
            }
            .padding(.top, 20)
        }
        .padding()
    }

    // MARK: - Networking

    private func validateForm() throws {
        if !isLogin {
            if fullName.isEmptyOrWhitespace {
                throw ValidationError.emptyFullname
            }
            if email.isEmptyOrWhitespace {
                throw ValidationError.emptyEmail
            }
        }
        if username.isEmptyOrWhitespace {
            throw ValidationError.emptyUsername
        }
        if password.isEmptyOrWhitespace {
            throw ValidationError.emptyPassword
        }
    }

    private func logIn() async {
        isLoading = true
        do {
            try validateForm()
            try await journalService.logIn(username: username, password: password)
        } catch {
            self.error = error
        }
        isLoading = false
    }

    private func register() async {
        isLoading = true
        do {
            try validateForm()
            try await journalService.register(fullname: fullName, email: email, username: username, password: password)
        } catch {
            self.error = error
        }
        isLoading = false
    }
    
    private func checkTokenExpiration() {
        guard journalService.tokenExpired else { return }
        
        error = SessionError.expired
    }
}

#Preview {
    AuthView()
}
