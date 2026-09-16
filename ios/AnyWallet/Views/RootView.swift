import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct RootView: View {
    @StateObject private var model = AppViewModel()
    @StateObject private var ads = AdService()
    @State private var isImporterPresented = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isLaunching = true

    var body: some View {
        ZStack {
            AppTheme.canvas.ignoresSafeArea()
            if model.analysis == nil && !model.isCustomMode {
                ImportView(
                    isAnalyzing: model.isAnalyzing,
                    selectedPhoto: $selectedPhoto,
                    onImportFile: { isImporterPresented = true },
                    onCreateCustom: model.startCustomPass,
                    showsAdPrivacyOptions: ads.privacyOptionsRequired,
                    onAdPrivacyOptions: ads.showPrivacyOptions
                )
            } else {
                TicketEditorView(model: model)
            }

            if model.isAnalyzing {
                LoadingOverlay(label: L10n.text("Analizando el pase"))
            }

            if isLaunching {
                LaunchView()
                    .transition(.opacity)
                    .zIndex(10)
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
            L10n.text("No se ha podido completar la operación"),
            isPresented: Binding(
                get: { model.errorMessage != nil },
                set: { if !$0 { model.errorMessage = nil } }
            )
        ) {
            Button(L10n.text("Aceptar"), role: .cancel) { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? L10n.text("Error desconocido"))
        }
        .sheet(item: $model.pendingWalletPass) { pending in
            WalletPassSheet(data: pending.data) { wasAdded in
                model.reset()
                if wasAdded { ads.showAfterSuccessfulPass() }
            }
        }
        .task {
            try? await Task.sleep(for: .milliseconds(650))
            withAnimation(.easeOut(duration: 0.22)) { isLaunching = false }
            ads.prepare()
        }
    }
}

private struct LaunchView: View {
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            VStack(spacing: 18) {
                Image("BrandMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 68, height: 68)
                Text("AnyWallet")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(AppTheme.ink)
                ProgressView().tint(AppTheme.accent)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(L10n.text("Abriendo AnyWallet"))
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
