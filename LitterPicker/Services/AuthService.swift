import Foundation
import FirebaseAuth
import AuthenticationServices
import CryptoKit

@Observable
final class AuthService: NSObject {
    private(set) var currentUser: FirebaseAuth.User?
    private(set) var isAnonymous: Bool = true

    private var currentNonce: String?
    private var appleSignInContinuation: CheckedContinuation<Void, Error>?
    private var authStateHandle: AuthStateDidChangeListenerHandle?

    override init() {
        super.init()
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.currentUser = user
            self?.isAnonymous = user?.isAnonymous ?? true
        }
    }

    deinit {
        if let handle = authStateHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

    var uid: String? { currentUser?.uid }
    var isAuthenticated: Bool { currentUser != nil }
    var isSignedIn: Bool { !(currentUser?.isAnonymous ?? true) }

    // MARK: - Anonymous sign-in

    func signInAnonymously() async throws {
        guard currentUser == nil else { return }
        let result = try await Auth.auth().signInAnonymously()
        currentUser = result.user
        isAnonymous = true
    }

    // MARK: - Sign in with Apple

    func startSignInWithApple() async throws {
        let nonce = randomNonceString()
        currentNonce = nonce

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.appleSignInContinuation = continuation
            let provider = ASAuthorizationAppleIDProvider()
            let request = provider.createRequest()
            request.requestedScopes = []
            request.nonce = sha256(nonce)

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.performRequests()
        }
    }

    // MARK: - Sign out

    func signOut() throws {
        try Auth.auth().signOut()
    }

    // MARK: - Nonce helpers

    private func randomNonceString(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        while remainingLength > 0 {
            let randoms: [UInt8] = (0..<16).map { _ in
                var random: UInt8 = 0
                _ = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                return random
            }
            for random in randoms where remainingLength > 0 {
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        return result
    }

    private func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension AuthService: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let appleCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let nonce = currentNonce,
              let tokenData = appleCredential.identityToken,
              let tokenString = String(data: tokenData, encoding: .utf8) else {
            appleSignInContinuation?.resume(throwing: AuthError.invalidCredential)
            appleSignInContinuation = nil
            return
        }

        let credential = OAuthProvider.credential(
            providerID: AuthProviderID.apple,
            idToken: tokenString,
            rawNonce: nonce
        )

        Task {
            do {
                if let user = self.currentUser, user.isAnonymous {
                    try await user.link(with: credential)
                } else {
                    try await Auth.auth().signIn(with: credential)
                }
                self.appleSignInContinuation?.resume()
            } catch {
                self.appleSignInContinuation?.resume(throwing: error)
            }
            self.appleSignInContinuation = nil
        }
    }

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithError error: Error) {
        appleSignInContinuation?.resume(throwing: error)
        appleSignInContinuation = nil
    }
}

enum AuthError: Error {
    case invalidCredential
}
