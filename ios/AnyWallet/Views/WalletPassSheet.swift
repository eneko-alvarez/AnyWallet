import PassKit
import SwiftUI

struct WalletPassSheet: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    let data: Data
    let onFinish: (Bool) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(data: data) { wasAdded in
            dismiss()
            onFinish(wasAdded)
        }
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
        private let pass: PKPass?
        private let wasAlreadyInLibrary: Bool
        private let completion: (Bool) -> Void

        init(data: Data, completion: @escaping (Bool) -> Void) {
            pass = try? PKPass(data: data)
            wasAlreadyInLibrary = pass.map { PKPassLibrary().containsPass($0) } ?? false
            self.completion = completion
        }

        func addPassesViewControllerDidFinish(_ controller: PKAddPassesViewController) {
            let wasAdded = !wasAlreadyInLibrary && (pass.map { PKPassLibrary().containsPass($0) } ?? false)
            completion(wasAdded)
        }
    }
}
