import PhotosUI
import SwiftUI

struct ImportView: View {
    let isAnalyzing: Bool
    @Binding var selectedPhoto: PhotosPickerItem?
    let onImportFile: () -> Void
    let onCreateCustom: () -> Void
    // Publicidad futura: reponer showsAdPrivacyOptions y onAdPrivacyOptions.

    @State private var isSourceDialogPresented = false
    @State private var isPhotoPickerPresented = false

    var body: some View {
        VStack(spacing: 0) {
            brand

            Spacer(minLength: 44)

            VStack(spacing: 22) {
                Image("WalletIcon")
                    .renderingMode(.original)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 76, height: 76)
                    .accessibilityHidden(true)

                VStack(spacing: 10) {
                    Text(L10n.text("Crea tu próximo pase."))
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(AppTheme.ink)
                        .multilineTextAlignment(.center)

                    Text(L10n.text("Billetes y tarjetas, listos para Apple Wallet."))
                        .font(.system(size: 17))
                        .foregroundStyle(AppTheme.muted)
                        .multilineTextAlignment(.center)
                }
            }

            Spacer(minLength: 52)

            VStack(spacing: 18) {
                Button {
                    isSourceDialogPresented = true
                } label: {
                    HStack(spacing: 9) {
                        if isAnalyzing {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "plus")
                                .fontWeight(.semibold)
                        }
                        Text(isAnalyzing ? L10n.text("Analizando…") : L10n.text("Crear pase"))
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(.black, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .disabled(isAnalyzing)

                Button(action: onCreateCustom) {
                    Label(L10n.text("Crear desde cero"), systemImage: "slider.horizontal.3")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppTheme.ink)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 12))
                        .overlay { RoundedRectangle(cornerRadius: 12).stroke(AppTheme.line) }
                }
                .buttonStyle(.plain)
                .disabled(isAnalyzing)

                Label(L10n.text("El archivo se analiza en este iPhone"), systemImage: "lock.fill")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.muted)

                Link(L10n.text("Política de privacidad"), destination: URL(string: "https://anywallet.topitup.party/privacy?lang=\(L10n.language)")!)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.muted)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 14)
        .padding(.bottom, 24)
        .background(Color.white.ignoresSafeArea())
        .confirmationDialog(
            L10n.text("Seleccionar origen"),
            isPresented: $isSourceDialogPresented,
            titleVisibility: .visible
        ) {
            Button(L10n.text("Foto de un billete o tarjeta")) { isPhotoPickerPresented = true }
            Button(L10n.text("PDF o imagen desde Archivos")) { onImportFile() }
            Button(L10n.text("Cancelar"), role: .cancel) {}
        }
        .photosPicker(
            isPresented: $isPhotoPickerPresented,
            selection: $selectedPhoto,
            matching: .images
        )
    }

    private var brand: some View {
        HStack(spacing: 10) {
            Image("BrandMark")
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .frame(width: 34, height: 34)
                .accessibilityHidden(true)
            Text("AnyWallet")
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(AppTheme.ink)
            Spacer()
            // Publicidad futura: mostrar aqui el acceso de UMP cuando sea requerido.
        }
    }
}
