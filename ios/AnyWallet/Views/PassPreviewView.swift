import SwiftUI

struct PassPreviewView: View {
    let passKind: PassKind
    let fields: TicketFields
    let barcode: BarcodeCandidate?
    let passColor: PassColor

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("AnyWallet").font(.headline.bold())
                    Spacer()
                    Text(passKind == .travel ? fields.reference : fields.memberNumber)
                        .font(.caption.bold())
                        .lineLimit(1)
                }

                Text(passKind == .travel ? "BILLETE PERSONAL" : "TARJETA DE MEMBRESÍA")
                    .font(.caption2.bold())
                    .foregroundStyle(.white.opacity(0.72))
                    .padding(.top, 18)
                Text(fields.title.isEmpty ? "—" : fields.title)
                    .font(.system(size: 27, weight: .bold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                    .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
                    .padding(.top, 5)

                if passKind == .travel {
                    HStack(alignment: .bottom, spacing: 10) {
                        place(label: "ORIGEN", value: fields.origin, isTrailing: false)
                        Image(systemName: "location.fill").font(.footnote).foregroundStyle(.white.opacity(0.82))
                        place(label: "DESTINO", value: fields.destination, isTrailing: true)
                    }
                    .padding(.bottom, 19)
                } else {
                    place(label: "PROGRAMA", value: fields.issuer, isTrailing: false)
                        .padding(.bottom, 19)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .foregroundStyle(.white)

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(passKind == .travel ? "FECHA Y HORA" : "TITULAR").font(.caption2.bold()).foregroundStyle(AppTheme.muted)
                    Text(primaryDetail)
                        .font(.subheadline.bold()).foregroundStyle(AppTheme.ink)
                    if !secondaryDetail.isEmpty {
                        Text(secondaryDetail).font(.caption).foregroundStyle(AppTheme.muted).lineLimit(1).padding(.top, 4)
                    }
                }
                Spacer()
                if let barcode {
                    Image(uiImage: barcode.preview)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 116, height: 84)
                } else {
                    Rectangle().fill(AppTheme.line).frame(width: 116, height: 84)
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

    private var primaryDetail: String {
        if passKind == .membership {
            return fields.memberName.isEmpty ? "Sin titular" : fields.memberName
        }
        return fields.relevantDate?.formatted(date: .abbreviated, time: .shortened) ?? "Sin fecha"
    }

    private var secondaryDetail: String {
        if passKind == .membership {
            return fields.memberNumber.isEmpty ? "" : "N.º \(fields.memberNumber)"
        }
        return fields.passenger
    }

    private func place(label: String, value: String, isTrailing: Bool) -> some View {
        VStack(alignment: isTrailing ? .trailing : .leading, spacing: 4) {
            Text(label).font(.caption2.bold()).foregroundStyle(.white.opacity(0.72))
            Text(value.isEmpty ? "—" : value).font(.subheadline.bold()).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: isTrailing ? .trailing : .leading)
    }
}
