import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct RootView: View {
    @StateObject private var model = AppViewModel()
    @State private var isImporterPresented = false
    @State private var selectedPhoto: PhotosPickerItem?

    var body: some View {
        ZStack {
            AppTheme.canvas.ignoresSafeArea()
            if model.analysis == nil {
                ImportView(
                    isAnalyzing: model.isAnalyzing,
                    selectedPhoto: $selectedPhoto,
                    onImportFile: { isImporterPresented = true }
                )
            } else {
                TicketEditorView(model: model)
            }

            if model.isAnalyzing {
                LoadingOverlay(label: "Analizando el pase")
            }
        }
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [.pdf, .image],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first { model.importFile(from: url) }
            case .failure(let error):
                model.errorMessage = error.localizedDescription
            }
        }
        .onChange(of: selectedPhoto) { _, item in
            guard let item else { return }
            Task {
                do {
                    guard let data = try await item.loadTransferable(type: Data.self) else {
                        throw AnyWalletError.invalidDocument
                    }
                    model.importImage(data: data)
                } catch {
                    model.errorMessage = error.localizedDescription
                }
                selectedPhoto = nil
            }
        }
        .alert(
            "No se ha podido completar la operación",
            isPresented: Binding(
                get: { model.errorMessage != nil },
                set: { if !$0 { model.errorMessage = nil } }
            )
        ) {
            Button("Aceptar", role: .cancel) { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "Error desconocido")
        }
        .sheet(item: $model.pendingWalletPass) { pending in
            WalletPassSheet(data: pending.data) {
                model.reset()
            }
        }
    }
}

private struct LoadingOverlay: View {
    let label: String

    var body: some View {
        ZStack {
            Color.black.opacity(0.24).ignoresSafeArea()
            VStack(spacing: 14) {
                ProgressView().tint(.white).controlSize(.large)
                Text(label).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
            }
            .frame(width: 210, height: 120)
            .background(AppTheme.ink.opacity(0.96), in: RoundedRectangle(cornerRadius: 8))
        }
        .accessibilityElement(children: .combine)
    }
}
