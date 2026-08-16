import SwiftUI
import UIKit

final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        let rootView = ShareRootView(
            extensionContext: extensionContext,
            onCancel: { [weak self] in
                self?.extensionContext?.cancelRequest(withError: ShareError.cancelled)
            },
            onComplete: { [weak self] in
                self?.extensionContext?.completeRequest(returningItems: nil)
            }
        )

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
    }
}

enum ShareError: LocalizedError {
    case cancelled
    case noYouTubeURL

    var errorDescription: String? {
        switch self {
        case .cancelled: return String(localized: "共有をキャンセルしました。")
        case .noYouTubeURL: return String(localized: "YouTubeのURLが見つかりませんでした。")
        }
    }
}
