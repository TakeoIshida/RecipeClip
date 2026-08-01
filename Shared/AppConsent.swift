enum AppConsent {
    static let currentPolicyVersion = SharedModelContainer.currentPrivacyPolicyVersion

    static var hasAcceptedCurrentPolicy: Bool {
        SharedModelContainer.hasAcceptedCurrentPrivacyPolicy
    }

    static func acceptCurrentPolicy() {
        SharedModelContainer.acceptCurrentPrivacyPolicy()
    }
}
