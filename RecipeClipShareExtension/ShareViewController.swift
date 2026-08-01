import SwiftData
import SwiftUI
import UIKit

final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        do {
            let container = try SharedModelContainer.make()
            let rootView = ShareRootView(
                extensionContext: extensionContext,
                onCancel: { [weak self] in
                    self?.extensionContext?.cancelRequest(withError: ShareError.cancelled)
                },
                onComplete: { [weak self] in
                    self?.extensionContext?.completeRequest(returningItems: nil)
                }
            )
            .modelContainer(container)

            let host = UIHostingController(rootView: rootView)
            addChild(host)
            host.view.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(host.view)
            NSLayoutConstraint.activate([
                host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                host.view.topAnchor.constraint(equalTo: view.topAnchor),
                host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
            host.didMove(toParent: self)
        } catch {
            extensionContext?.cancelRequest(withError: error)
        }
    }
}

enum ShareError: LocalizedError {
    case cancelled
    case noYouTubeURL
    case consentRequired

    var errorDescription: String? {
        switch self {
        case .cancelled: return "共有をキャンセルしました。"
        case .noYouTubeURL: return "YouTubeのURLが見つかりませんでした。"
        case .consentRequired: return "先にレシピクリップ本体を開いて、プライバシーポリシーへ同意してね。"
        }
    }
}
