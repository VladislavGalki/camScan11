import SwiftUI

struct PasswordDocumentView: View {
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var shouldShowInvalidPasswordOverlay: Bool = false
    @Binding private var currentPassword: String?
    
    @Environment(\.dismiss) private var dismiss
    
    init(currentPassword: Binding<String?>) {
        password = currentPassword.wrappedValue ?? ""
        confirmPassword = currentPassword.wrappedValue ?? ""
        _currentPassword = currentPassword
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            navigationView
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            
            passwordInputView
                .padding(.horizontal, 16)
            
            Spacer(minLength: 0)
        }
        .background(
            Color.bg(.main)
                .ignoresSafeArea()
        )
        .overlay {
            if shouldShowInvalidPasswordOverlay {
                invalidOverlayView
            }
        }
    }
    
    private var navigationView: some View {
        HStack(spacing: 10) {
            AppButton(
                config: AppButtonConfig(
                    content: .iconOnly(.close),
                    style: .secondary,
                    size: .m
                ),
                action: {
                    dismiss()
                }
            )
            
            Text("Set password")
                .appTextStyle(.topBarTitle)
                .foregroundStyle(.text(.primary))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            
            AppButton(
                config: AppButtonConfig(
                    content: .iconOnly(.check),
                    style: .primary,
                    size: .m
                ),
                action: {
                    if isPasswordValid {
                        currentPassword = password
                        dismiss()
                    } else {
                        shouldShowInvalidPasswordOverlay = true
                    }
                }
            )
            .appButtonEnabled(!password.isEmpty && !confirmPassword.isEmpty)
        }
        .padding(.vertical, 12)
    }
    
    private var passwordInputView: some View {
        VStack(alignment: .leading, spacing: 24) {
            passwordTextFieldView
            
            confirmPasswordTextFieldView
        }
    }
    
    private var passwordTextFieldView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Password")
                .appTextStyle(.bodySecondary)
                .foregroundStyle(.text(.secondary))
            
            PasswordField(password: $password)
        }
    }
    
    private var confirmPasswordTextFieldView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Confirm password")
                .appTextStyle(.bodySecondary)
                .foregroundStyle(.text(.secondary))
            
            PasswordField(password: $confirmPassword)
        }
    }
    
    private var invalidOverlayView: some View {
        ZStack {
            Color.black.opacity(0.24)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Text("Passwords Don’t Match")
                    .appTextStyle(.itemTitle)
                    .foregroundStyle(.text(.primary))
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 8)
                
                Text("Please re-enter your new password.")
                    .appTextStyle(.bodyPrimary)
                    .foregroundStyle(.text(.secondary))
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 24)
                
                AppButton(
                    config: AppButtonConfig(
                        content: .title("Got it"),
                        style: .primary,
                        size: .l,
                        isFullWidth: true
                    ),
                    action: {
                        shouldShowInvalidPasswordOverlay = false
                    }
                )
            }
            .padding(16)
            .frame(width: 300)
            .background(
                Color.bg(.surface)
                    .cornerRadius(24, corners: .allCorners)
            )
        }
    }
    
    private var isPasswordValid: Bool {
        password == confirmPassword
    }
}

struct PasswordField: View {
    @Binding var password: String
    @State private var isVisible: Bool = false
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Group {
                if isVisible {
                    TextField("", text: $password)
                        .focused($isFocused)
                        .onSubmit {
                            isFocused = false
                        }
                } else {
                    SecureField("", text: $password)
                        .focused($isFocused)
                        .onSubmit {
                            isFocused = false
                        }
                }
            }
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .appTextStyle(.bodySecondary)
            .foregroundStyle(.black)
            .tint(.bg(.accent))
            .background(Color.clear)
            
            if !password.isEmpty {
                Image(appIcon: isVisible ? .eye_splash : .eye)
                    .renderingMode(.template)
                    .foregroundStyle(.elements(.tertiary))
                    .onTapGesture {
                        isVisible.toggle()
                        
                        DispatchQueue.main.async {
                            isFocused = true
                        }
                    }
            }
        }
        .padding(.leading, 16)
        .padding(.trailing, 8)
        .frame(height: 44)
        .background(
            Color.bg(.controlOnMain)
                .cornerRadius(12, corners: .allCorners)
        )
        .onChange(of: password) { _, newValue in
            let filtered = newValue.filter(\.isASCII)
            
            if filtered != newValue {
                password = filtered
            }
        }
    }
}
