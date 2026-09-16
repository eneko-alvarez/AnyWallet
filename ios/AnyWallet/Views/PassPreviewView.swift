import SwiftUI

struct PassPreviewView: View {
    let passKind: PassKind
    let fields: TicketFields
    let barcode: BarcodeCandidate?
    let passColor: PassColor
    let customFields: [CustomPassField]
    let customPhotoData: Data?
    let photoAspect: PhotoAspect

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("AnyWallet").font(.headline.bold())
                    Spacer()
                    Text(headerValue)
                        .font(.caption.bold())
                        .lineLimit(1)
                }

                Text(kindLabel)
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
                        place(label: L10n.text("ORIGEN"), value: fields.origin, isTrailing: false)
                        Image(systemName: "location.fill").font(.footnote).foregroundStyle(.white.opacity(0.82))
                        place(label: L10n.text("DESTINO"), value: fields.destination, isTrailing: true)
                    }
                    .padding(.bottom, 19)
                } else if passKind == .membership {
                    place(label: L10n.text("PROGRAMA"), value: fields.issuer, isTrailing: false)
                        .padding(.bottom, 19)
                } else {
                    HStack(alignment: .top, spacing: 14) {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(customFields.prefix(2)) { field in
                                place(label: field.label.uppercased(), value: field.value, isTrailing: false)
                            }
                        }
                        if let customPhotoData, let image = UIImage(data: customPhotoData) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 82, height: min(104, 82 / photoAspect.ratio))
                                .clipShape(RoundedRectangle(cornerRadius: 7))
                        }
                    }
                    .padding(.bottom, 19)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .foregroundStyle(.white)

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(detailLabel).font(.caption2.bold()).foregroundStyle(AppTheme.muted)
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
        if passKind == .custom {
            return customFields.dropFirst(2).first?.value.nonEmpty ?? L10n.text("Pase personal")
        }
        if passKind == .membership {
            return fields.memberName.isEmpty ? L10n.text("Sin titular") : fields.memberName
        }
        return fields.relevantDate?.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened).locale(L10n.locale)) ?? L10n.text("Sin fecha")
    }

    private var secondaryDetail: String {
        if passKind == .custom { return customFields.dropFirst(3).first?.value ?? "" }
        if passKind == .membership {
            return fields.memberNumber.isEmpty ? "" : L10n.format("N.º %@", fields.memberNumber)
        }
        return fields.passenger
    }

    private var headerValue: String {
        switch passKind {
        case .travel: fields.reference
        case .membership: fields.memberNumber
        case .custom: customFields.first?.value ?? ""
        }
    }

    private var kindLabel: String {
        switch passKind {
        case .travel: L10n.text("BILLETE PERSONAL")
        case .membership: L10n.text("TARJETA DE MEMBRESÍA")
        case .custom: L10n.text("PASE PERSONALIZADO")
        }
    }

    private var detailLabel: String {
        switch passKind {
        case .travel: L10n.text("FECHA Y HORA")
        case .membership: L10n.text("TITULAR")
        case .custom: customFields.dropFirst(2).first?.label.uppercased() ?? L10n.text("DETALLE")
        }
    }

    private func place(label: String, value: String, isTrailing: Bool) -> some View {
        VStack(alignment: isTrailing ? .trailing : .leading, spacing: 4) {
            Text(label).font(.caption2.bold()).foregroundStyle(.white.opacity(0.72))
            Text(value.isEmpty ? "—" : value).font(.subheadline.bold()).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: isTrailing ? .trailing : .leading)
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
