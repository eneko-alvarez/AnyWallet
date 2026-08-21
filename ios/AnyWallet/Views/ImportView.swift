import SwiftUI

struct ImportView: View {
    let isAnalyzing: Bool
    let onImport: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "wallet.pass.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(AppTheme.ink, in: RoundedRectangle(cornerRadius: 8))
                    Text("AnyWallet")
                        .font(.title3.bold())
                        .foregroundStyle(AppTheme.ink)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("NUEVO PASE")
                        .font(.caption.bold())
                        .foregroundStyle(AppTheme.accent)
                    Text("Tu billete, listo en Wallet.")
                        .font(.system(size: 38, weight: .bold))
                        .foregroundStyle(AppTheme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 72)

                Button(action: onImport) {
                    VStack(spacing: 16) {
                        Image(systemName: "doc.badge.plus")
                            .font(.system(size: 27, weight: .medium))
                            .foregroundStyle(AppTheme.accent)
                            .frame(width: 54, height: 54)
                            .background(AppTheme.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                        VStack(spacing: 7) {
                            Text(isAnalyzing ? "Analizando el billete…" : "Seleccionar PDF")
                                .font(.headline)
                                .foregroundStyle(AppTheme.ink)
                            Text("Hasta 15 MB · 12 páginas")
                                .font(.footnote)
                                .foregroundStyle(AppTheme.muted)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 210)
                    .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(AppTheme.line, style: StrokeStyle(lineWidth: 1.5, dash: [7]))
                    }
                }
                .buttonStyle(.plain)
                .disabled(isAnalyzing)
                .padding(.top, 42)

                Label("El documento se analiza en este iPhone y no se sube.", systemImage: "lock.fill")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.muted)
                    .padding(.horizontal, 8)
                    .padding(.top, 18)
            }
            .padding(.horizontal, 22)
            .padding(.top, 16)
            .padding(.bottom, 36)
        }
    }
}
