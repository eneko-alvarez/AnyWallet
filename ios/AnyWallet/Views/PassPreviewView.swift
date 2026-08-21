import SwiftUI

struct PassPreviewView: View {
    let fields: TicketFields
    let qrCode: QRCodeCandidate?
    let passColor: PassColor

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("AnyWallet").font(.headline.bold())
                    Spacer()
                    Text(fields.reference).font(.caption.bold()).lineLimit(1)
                }

                Text("BILLETE PERSONAL")
                    .font(.caption2.bold())
                    .foregroundStyle(.white.opacity(0.72))
                    .padding(.top, 18)
                Text(fields.title.isEmpty ? "—" : fields.title)
                    .font(.system(size: 27, weight: .bold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                    .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
                    .padding(.top, 5)

                HStack(alignment: .bottom, spacing: 10) {
                    place(label: "ORIGEN", value: fields.origin, isTrailing: false)
                    Image(systemName: "location.fill").font(.footnote).foregroundStyle(.white.opacity(0.82))
                    place(label: "DESTINO", value: fields.destination, isTrailing: true)
                }
                .padding(.bottom, 19)
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .foregroundStyle(.white)

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("FECHA Y HORA").font(.caption2.bold()).foregroundStyle(AppTheme.muted)
                    Text(fields.relevantDate?.formatted(date: .abbreviated, time: .shortened) ?? "Sin fecha")
                        .font(.subheadline.bold()).foregroundStyle(AppTheme.ink)
                    if !fields.passenger.isEmpty {
                        Text(fields.passenger).font(.caption).foregroundStyle(AppTheme.muted).lineLimit(1).padding(.top, 4)
                    }
                }
                Spacer()
                if let qrCode {
                    Image(uiImage: qrCode.preview)
                        .interpolation(.none)
                        .resizable()
                        .frame(width: 84, height: 84)
                } else {
                    Rectangle().fill(AppTheme.line).frame(width: 84, height: 84)
                }
            }
            .padding(16)
            .frame(minHeight: 116)
            .background(.white)
        }
        .background(passColor.color)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
    }

    private func place(label: String, value: String, isTrailing: Bool) -> some View {
        VStack(alignment: isTrailing ? .trailing : .leading, spacing: 4) {
            Text(label).font(.caption2.bold()).foregroundStyle(.white.opacity(0.72))
            Text(value.isEmpty ? "—" : value).font(.subheadline.bold()).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: isTrailing ? .trailing : .leading)
    }
}
