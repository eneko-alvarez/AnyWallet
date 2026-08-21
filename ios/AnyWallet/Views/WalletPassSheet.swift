import PassKit
import SwiftUI

struct WalletPassSheet: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    let data: Data

    func makeCoordinator() -> Coordinator {
        Coordinator { dismiss() }
    }

    func makeUIViewController(context: Context) -> UIViewController {
        guard let pass = try? PKPass(data: data),
              let controller = PKAddPassesViewController(pass: pass) else {
            let controller = UIViewController()
            controller.view.backgroundColor = .systemBackground
            return controller
        }
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    final class Coordinator: NSObject, PKAddPassesViewControllerDelegate {
        private let onFinish: () -> Void

        init(onFinish: @escaping () -> Void) {
            self.onFinish = onFinish
        }

        func addPassesViewControllerDidFinish(_ controller: PKAddPassesViewController) {
            onFinish()
        }
    }
}
